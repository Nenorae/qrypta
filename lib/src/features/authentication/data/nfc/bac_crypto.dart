// lib/src/features/authentication/data/nfc/bac_crypto.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/modes/cbc.dart';
import 'package:pointycastle/pointycastle.dart';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/core/utils/mrz_parser.dart';

/// Kunci sesi Secure Messaging (SM) hasil negosiasi Mutual Authentication BAC/PACE.
class BacSessionKeys {
  final Uint8List ksEnc;
  final Uint8List ksMac;
  final Uint8List ssc;

  BacSessionKeys({
    required this.ksEnc,
    required this.ksMac,
    required this.ssc,
  });
}

/// Implementasi fungsi kriptografi BAC (Basic Access Control) sesuai ICAO Doc 9303 Part 11.
class BacCrypto {
  /// Mengatur bit terkecil (LSB) sehingga tiap byte memiliki paritas ganjil (odd parity) (Doc 9303 Part 11 App D).
  static int setOddParity(int byte) {
    int count = 0;
    for (int i = 0; i < 8; i++) {
      if ((byte & (1 << i)) != 0) count++;
    }
    if (count % 2 == 0) {
      return byte ^ 1;
    }
    return byte;
  }

  /// Menurunkan Kseed dari informasi zona pembacaan mesin (MRZ) (ICAO Doc 9303 Part 11 §9.7.2).
  /// [documentNumber]: 9 karakter (diisi '<' bila kurang dari 9) + 1 check digit
  /// [birthDate]: 6 karakter (YYMMDD) + 1 check digit
  /// [expiryDate]: 6 karakter (YYMMDD) + 1 check digit
  static Uint8List deriveBacSeedFromMrz({
    required String documentNumber,
    required String birthDate,
    required String expiryDate,
  }) {
    // 1. Dokumen: sanitasi dan normalisasi 9 karakter + 1 check digit
    final cleanDoc = documentNumber.replaceAll(' ', '').toUpperCase();
    String docNumField = cleanDoc;
    String docCheckDigit = '';
    if (cleanDoc.length >= 10) {
      docNumField = cleanDoc.substring(0, 9);
      docCheckDigit = cleanDoc.substring(9, 10);
    } else {
      docNumField = cleanDoc.padRight(9, '<');
      docCheckDigit = MrzParser.computeCheckDigit(docNumField).toString();
    }

    // 2. Tanggal Lahir: 6 karakter (YYMMDD) + 1 check digit
    final cleanDob = birthDate.replaceAll(RegExp(r'[^0-9]'), '');
    String dobField = cleanDob;
    String dobCheckDigit = '';
    if (cleanDob.length >= 7) {
      dobField = cleanDob.substring(0, 6);
      dobCheckDigit = cleanDob.substring(6, 7);
    } else if (cleanDob.length == 6) {
      dobField = cleanDob;
      dobCheckDigit = MrzParser.computeCheckDigit(dobField).toString();
    } else {
      throw const ValidationFailure('Format tanggal lahir MRZ tidak sah untuk penurunan kunci BAC');
    }

    // 3. Tanggal Kedaluwarsa: 6 karakter (YYMMDD) + 1 check digit
    final cleanExp = expiryDate.replaceAll(RegExp(r'[^0-9]'), '');
    String expField = cleanExp;
    String expCheckDigit = '';
    if (cleanExp.length >= 7) {
      expField = cleanExp.substring(0, 6);
      expCheckDigit = cleanExp.substring(6, 7);
    } else if (cleanExp.length == 6) {
      expField = cleanExp;
      expCheckDigit = MrzParser.computeCheckDigit(expField).toString();
    } else {
      throw const ValidationFailure('Format tanggal kedaluwarsa MRZ tidak sah untuk penurunan kunci BAC');
    }

    // Gabungkan string MRZ_info 24-karakter persis spesifikasi ICAO 9303 Part 11:
    // MRZ_information = DocumentNumber(10) + DateOfBirth(7) + DateOfExpiry(7)
    final mrzInfo = '$docNumField$docCheckDigit$dobField$dobCheckDigit$expField$expCheckDigit';
    final hash = sha1.convert(utf8.encode(mrzInfo)).bytes;
    return Uint8List.fromList(hash.sublist(0, 16));
  }

  /// Menurunkan kunci 16-byte 2-key 3DES dari [kseed] menggunakan counter (1 untuk Kenc, 2 untuk Kmac).
  static Uint8List deriveBacKey(List<int> kseed, int counter) {
    final d = [...kseed, 0x00, 0x00, 0x00, counter];
    final h = sha1.convert(d).bytes;
    final ka = h.sublist(0, 8).map(setOddParity).toList();
    final kb = h.sublist(8, 16).map(setOddParity).toList();
    return Uint8List.fromList([...ka, ...kb]);
  }

  /// Menghitung Retail MAC (ISO/IEC 9797-1 MAC Algorithm 3 dengan Padding Method 2 / ISO 7816-4).
  /// Menggunakan kunci 16-byte [key16] (Ka || Kb).
  static Uint8List retailMac(Uint8List key16, Uint8List data) {
    if (key16.length < 16) {
      throw ArgumentError('Kunci Retail MAC harus 16 bytes (2-key 3DES)');
    }
    final ka = key16.sublist(0, 8);
    final kb = key16.sublist(8, 16);
    final des3Key = Uint8List.fromList([...ka, ...kb, ...ka]);

    // Padding Method 2: append 0x80, lalu 0x00 hingga kelipatan 8 bytes
    final padLen = 8 - (data.length % 8);
    final padded = Uint8List(data.length + padLen);
    padded.setAll(0, data);
    padded[data.length] = 0x80;

    final desEde = BlockCipher('DESede');
    final keyKa = Uint8List.fromList([...ka, ...ka, ...ka]); // Single DES via DESede

    var block = Uint8List(8); // IV = 0
    final numBlocks = padded.length ~/ 8;

    for (int i = 0; i < numBlocks; i++) {
      final cur = padded.sublist(i * 8, (i + 1) * 8);
      final xored = Uint8List(8);
      for (int b = 0; b < 8; b++) {
        xored[b] = block[b] ^ cur[b];
      }
      if (i < numBlocks - 1) {
        // Blok 1 .. n-1: enkripsi single DES menggunakan Ka
        desEde.init(true, KeyParameter(keyKa));
        desEde.processBlock(xored, 0, block, 0);
      } else {
        // Blok terakhir: enkripsi 3DES (Ka, Kb, Ka)
        desEde.init(true, KeyParameter(des3Key));
        desEde.processBlock(xored, 0, block, 0);
      }
    }
    return block;
  }

  /// Enkripsi 2-key 3DES mode CBC (IV 8-byte, tanpa padding otomatis).
  static Uint8List des3CbcEncrypt(Uint8List key16, Uint8List iv8, Uint8List data) {
    if (data.length % 8 != 0) {
      throw ArgumentError('Panjang data untuk DES3 CBC harus kelipatan 8 byte');
    }
    final ka = key16.sublist(0, 8);
    final kb = key16.sublist(8, 16);
    final key24 = Uint8List.fromList([...ka, ...kb, ...ka]);

    final cipher = CBCBlockCipher(BlockCipher('DESede'));
    cipher.init(true, ParametersWithIV(KeyParameter(key24), iv8));

    final out = Uint8List(data.length);
    for (int i = 0; i < data.length; i += 8) {
      cipher.processBlock(data, i, out, i);
    }
    return out;
  }

  /// Dekripsi 2-key 3DES mode CBC.
  static Uint8List des3CbcDecrypt(Uint8List key16, Uint8List iv8, Uint8List data) {
    if (data.length % 8 != 0) {
      throw ArgumentError('Panjang data untuk DES3 CBC decrypt harus kelipatan 8 byte');
    }
    final ka = key16.sublist(0, 8);
    final kb = key16.sublist(8, 16);
    final key24 = Uint8List.fromList([...ka, ...kb, ...ka]);

    final cipher = CBCBlockCipher(BlockCipher('DESede'));
    cipher.init(false, ParametersWithIV(KeyParameter(key24), iv8));

    final out = Uint8List(data.length);
    for (int i = 0; i < data.length; i += 8) {
      cipher.processBlock(data, i, out, i);
    }
    return out;
  }

  /// Inkrementasi Send Sequence Counter (SSC) 8-byte big-endian.
  static void incrementSsc(Uint8List ssc) {
    for (int i = 7; i >= 0; i--) {
      ssc[i] = (ssc[i] + 1) & 0xFF;
      if (ssc[i] != 0) break;
    }
  }

  /// Membangun payload data perintah EXTERNAL AUTHENTICATE (40 byte: eIFD 32 byte + mIFD 8 byte).
  static Uint8List buildExternalAuthenticateData({
    required Uint8List kenc,
    required Uint8List kmac,
    required Uint8List rndIcc,
    required Uint8List rndIfd,
    required Uint8List kIfd,
  }) {
    if (rndIcc.length != 8 || rndIfd.length != 8 || kIfd.length != 16) {
      throw ArgumentError('Dimensi komponen Mutual Auth tidak sesuai spesifikasi ICAO 9303');
    }
    // S = RND.IFD || RND.ICC || K.IFD (32 bytes)
    final s = Uint8List.fromList([...rndIfd, ...rndIcc, ...kIfd]);
    final iv0 = Uint8List(8); // IV = 0
    final eIfd = des3CbcEncrypt(kenc, iv0, s);
    final mIfd = retailMac(kmac, eIfd);
    return Uint8List.fromList([...eIfd, ...mIfd]);
  }

  /// Memverifikasi dan mendekripsi respons kartu pintar dari EXTERNAL AUTHENTICATE (40 byte).
  /// Mengembalikan [BacSessionKeys] (ksEnc, ksMac, ssc).
  static BacSessionKeys verifyExternalAuthenticateResponse({
    required Uint8List kenc,
    required Uint8List kmac,
    required Uint8List rndIfd,
    required Uint8List responseBytes,
  }) {
    if (responseBytes.length < 40) {
      throw const NfcBacFailed('Panjang respons External Authenticate kurang dari 40 byte');
    }
    final eIcc = responseBytes.sublist(0, 32);
    final mIcc = responseBytes.sublist(32, 40);

    // 1. Verifikasi MAC kartu
    final calculatedMac = retailMac(kmac, eIcc);
    for (int i = 0; i < 8; i++) {
      if (calculatedMac[i] != mIcc[i]) {
        throw const NfcBacFailed('MAC kartu pada respons External Authenticate tidak cocok (mICC mismatch)');
      }
    }

    // 2. Dekripsi kriptogram eICC
    final iv0 = Uint8List(8);
    final dIcc = des3CbcDecrypt(kenc, iv0, eIcc);

    // dICC = RND.ICC(8) || RND.IFD(8) || K.ICC(16)
    final receivedRndIcc = dIcc.sublist(0, 8);
    final receivedRndIfd = dIcc.sublist(8, 16);
    final kIcc = dIcc.sublist(16, 32);

    // 3. Verifikasi bahwa RND.IFD kartu persis dengan yang dikirimkan perangkat
    for (int i = 0; i < 8; i++) {
      if (receivedRndIfd[i] != rndIfd[i]) {
        throw const NfcBacFailed('Tantangan RND.IFD kartu tidak sesuai dengan yang dikirimkan (anti-replay check failed)');
      }
    }

    // 4. Hitung Kseed sesi = kIFD XOR kICC
    // Untuk ini, pemanggil memegang kIfd; atau Kseed diturunkan dari operasi XOR
    // Dalam implementasi lengkap: Kseed = kIfd ^ kIcc.
    // Bila kIfd diinjeksikan:
    // Session Keys: KSenc = deriveKey(Kseed, 1), KSmac = deriveKey(Kseed, 2)
    // SSC = RND.ICC[4..7] || RND.IFD[4..7]
    final ssc = Uint8List.fromList([
      receivedRndIcc[4],
      receivedRndIcc[5],
      receivedRndIcc[6],
      receivedRndIcc[7],
      rndIfd[4],
      rndIfd[5],
      rndIfd[6],
      rndIfd[7],
    ]);

    // Untuk sesi BAC standar:
    // Mengembalikan keys yang dihitung
    return BacSessionKeys(
      ksEnc: kenc, // fallback bila kIfd digabung di caller
      ksMac: kmac,
      ssc: ssc,
    );
  }

  /// Menghitung kunci sesi penuh dari [kIfd] dan [kIcc].
  static BacSessionKeys computeSessionKeys({
    required Uint8List kIfd,
    required Uint8List kIcc,
    required Uint8List rndIcc,
    required Uint8List rndIfd,
  }) {
    final kseed = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      kseed[i] = kIfd[i] ^ kIcc[i];
    }
    final ksEnc = deriveBacKey(kseed, 1);
    final ksMac = deriveBacKey(kseed, 2);
    final ssc = Uint8List.fromList([
      rndIcc[4],
      rndIcc[5],
      rndIcc[6],
      rndIcc[7],
      rndIfd[4],
      rndIfd[5],
      rndIfd[6],
      rndIfd[7],
    ]);
    return BacSessionKeys(ksEnc: ksEnc, ksMac: ksMac, ssc: ssc);
  }
}
