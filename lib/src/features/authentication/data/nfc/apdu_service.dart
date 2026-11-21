// lib/src/features/authentication/data/nfc/apdu_service.dart

import 'dart:typed_data';
import 'package:qrypta/src/core/error/app_failure.dart';
import 'package:qrypta/src/features/authentication/data/nfc/bac_crypto.dart';
import 'package:qrypta/src/features/authentication/data/nfc/iso_dep_transceiver.dart';

/// Service penanganan format APDU pintar ISO 7816-4 dan enkapsulasi Secure Messaging (SM) ICAO Doc 9303 Part 11.
class ApduService {
  /// AID resmi e-Passport ICAO (A0000002471001).
  static final Uint8List passportAid = Uint8List.fromList([
    0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01,
  ]);

  /// File ID untuk Elementary Files ePassport:
  static final Uint8List fileIdEfCom = Uint8List.fromList([0x01, 0x1E]);
  static final Uint8List fileIdDg1   = Uint8List.fromList([0x01, 0x01]);
  static final Uint8List fileIdDg2   = Uint8List.fromList([0x01, 0x02]);
  static final Uint8List fileIdEfSod = Uint8List.fromList([0x01, 0x1D]);

  /// Memilih aplikasi ICAO ePassport melalui AID (SELECT APPLICATION by Name).
  static Future<void> selectPassportApplication(IsoDepTransceiver transceiver) async {
    // CLA=00, INS=A4, P1=04, P2=0C, Lc=07, Data=A0000002471001
    final apdu = Uint8List.fromList([
      0x00, 0xA4, 0x04, 0x0C, passportAid.length, ...passportAid,
    ]);
    final resp = await transceiver.transceive(apdu);
    _assertStatusWord(resp, 'Select ePassport application (AID: A0000002471001)');
  }

  /// Meminta bilangan acak 8-byte dari chip paspor (GET CHALLENGE).
  static Future<Uint8List> getChallenge(IsoDepTransceiver transceiver) async {
    // CLA=00, INS=84, P1=00, P2=00, Le=08
    final apdu = Uint8List.fromList([0x00, 0x84, 0x00, 0x00, 0x08]);
    final resp = await transceiver.transceive(apdu);
    _assertStatusWord(resp, 'GET CHALLENGE');
    if (resp.length < 10) {
      throw const NfcApduException('Panjang respons GET CHALLENGE kurang dari 8 byte');
    }
    return resp.sublist(0, 8);
  }

  /// Mengirimkan perintah EXTERNAL AUTHENTICATE dengan payload data 40 byte.
  static Future<Uint8List> externalAuthenticate(
    IsoDepTransceiver transceiver,
    Uint8List authData40,
  ) async {
    // CLA=00, INS=82, P1=00, P2=00, Lc=28 (40), Data=..., Le=28
    final apdu = Uint8List.fromList([
      0x00, 0x82, 0x00, 0x00, authData40.length, ...authData40, 0x28,
    ]);
    final resp = await transceiver.transceive(apdu);
    _assertStatusWord(resp, 'EXTERNAL AUTHENTICATE');
    if (resp.length < 42) {
      throw const NfcBacFailed('Panjang kriptogram balasan EXTERNAL AUTHENTICATE tidak valid');
    }
    return resp.sublist(0, 40);
  }

  /// Membaca file utuh secara lengkap (EF.COM, DG1, EF.SOD) dengan chunking otomatis dan Secure Messaging.
  static Future<Uint8List> readFullElementaryFile(
    IsoDepTransceiver transceiver,
    Uint8List fileId,
    BacSessionKeys? sessionKeys,
  ) async {
    // 1. SELECT FILE
    await selectFile(transceiver, fileId, sessionKeys);

    // 2. Baca 4 byte pertama untuk mendeteksi panjang total file dari Tag ASN.1
    final headerBytes = await readBinary(transceiver, 0, 4, sessionKeys);
    if (headerBytes.isEmpty) {
      throw const NfcApduException('Header ASN.1 file paspor kosong');
    }

    // Hitung panjang file dari header ASN.1
    final totalLength = _extractAsn1Length(headerBytes);
    final buffer = BytesBuilder();
    buffer.add(headerBytes);

    int currentOffset = headerBytes.length;
    const int chunkSize = 128; // Ukuran chunk aman untuk kartu IsoDep APDU

    while (currentOffset < totalLength) {
      final int remaining = totalLength - currentOffset;
      final int toRead = remaining > chunkSize ? chunkSize : remaining;
      final chunk = await readBinary(transceiver, currentOffset, toRead, sessionKeys);
      if (chunk.isEmpty) {
        throw NfcApduException('Membaca binary berhenti prematur pada offset $currentOffset');
      }
      buffer.add(chunk);
      currentOffset += chunk.length;
    }

    return buffer.toBytes();
  }

  /// Memilih file berdasarkan File ID (2 byte).
  static Future<void> selectFile(
    IsoDepTransceiver transceiver,
    Uint8List fileId,
    BacSessionKeys? sessionKeys,
  ) async {
    // CLA=00, INS=A4, P1=02, P2=0C, Lc=02, Data=fileId
    final rawCommand = Uint8List.fromList([
      0x00, 0xA4, 0x02, 0x0C, 0x02, ...fileId,
    ]);
    final response = await _transceiveWrapped(transceiver, rawCommand, sessionKeys);
    _assertStatusWord(response, 'SELECT FILE (${_bytesToHex(fileId)})');
  }

  /// Membaca potongan byte data (READ BINARY) pada [offset] sepanjang [length].
  static Future<Uint8List> readBinary(
    IsoDepTransceiver transceiver,
    int offset,
    int length,
    BacSessionKeys? sessionKeys,
  ) async {
    final p1 = (offset >> 8) & 0xFF;
    final p2 = offset & 0xFF;
    // CLA=00, INS=B0, P1, P2, Le=length
    final rawCommand = Uint8List.fromList([
      0x00, 0xB0, p1, p2, length,
    ]);
    final response = await _transceiveWrapped(transceiver, rawCommand, sessionKeys);
    _assertStatusWord(response, 'READ BINARY (offset: $offset, len: $length)');
    // Kembalikan data murni tanpa SW1-SW2 di ujung
    return response.sublist(0, response.length - 2);
  }

  /// Mengirim APDU dengan atau tanpa proteksi Secure Messaging (SM).
  static Future<Uint8List> _transceiveWrapped(
    IsoDepTransceiver transceiver,
    Uint8List plainApdu,
    BacSessionKeys? keys,
  ) async {
    if (keys == null) {
      return await transceiver.transceive(plainApdu);
    }
    // Bila Secure Messaging aktif, enkapsulasi APDU dengan DO'87, DO'97, dan DO'8E
    final protectedApdu = _wrapSecureMessaging(plainApdu, keys);
    final protectedResp = await transceiver.transceive(protectedApdu);
    return _unwrapSecureMessaging(protectedResp, keys);
  }

  /// Membungkus APDU plaintext menjadi protected APDU dengan Secure Messaging ICAO 9303 Part 11.
  static Uint8List _wrapSecureMessaging(Uint8List plainApdu, BacSessionKeys keys) {
    final int cla = plainApdu[0] | 0x0C; // Masked CLA
    final int ins = plainApdu[1];
    final int p1 = plainApdu[2];
    final int p2 = plainApdu[3];

    final builder = BytesBuilder();
    // 1. Kriptogram data (DO'87) bila ada data
    bool hasData = plainApdu.length > 5;
    Uint8List? do87;
    if (hasData) {
      final lc = plainApdu[4];
      final data = plainApdu.sublist(5, 5 + lc);
      // Padding method 2
      final padLen = 8 - (data.length % 8);
      final paddedData = Uint8List(data.length + padLen);
      paddedData.setAll(0, data);
      paddedData[data.length] = 0x80;

      // IV dihitung dengan mengenkripsi SSC menggunakan KSenc
      final iv = BacCrypto.des3CbcEncrypt(keys.ksEnc, Uint8List(8), keys.ssc);
      final encrypted = BacCrypto.des3CbcEncrypt(keys.ksEnc, iv, paddedData);

      final do87Payload = Uint8List.fromList([0x01, ...encrypted]); // 0x01 = padding indicator
      do87 = Uint8List.fromList([0x87, do87Payload.length, ...do87Payload]);
      builder.add(do87);
    }

    // 2. Le (DO'97) bila ada Le di akhir
    Uint8List? do97;
    if (plainApdu.length == 5 || (hasData && plainApdu.length > 5 + plainApdu[4])) {
      final int le = plainApdu.last;
      do97 = Uint8List.fromList([0x97, 0x01, le]);
      builder.add(do97);
    }

    // 3. Inkrementasi SSC sebelum menghitung MAC
    BacCrypto.incrementSsc(keys.ssc);

    // 4. Hitung Retail MAC (DO'8E)
    // Data to MAC: SSC(8) || Padded Masked Header(8: CLA INS P1 P2 80 00 00 00) || DO87 || DO97
    final macInputBuilder = BytesBuilder();
    macInputBuilder.add(keys.ssc);
    macInputBuilder.add([cla, ins, p1, p2, 0x80, 0x00, 0x00, 0x00]);
    if (do87 != null) macInputBuilder.add(do87);
    if (do97 != null) macInputBuilder.add(do97);

    final mac = BacCrypto.retailMac(keys.ksMac, macInputBuilder.toBytes());
    final do8E = Uint8List.fromList([0x8E, 0x08, ...mac]);
    builder.add(do8E);

    final body = builder.toBytes();
    return Uint8List.fromList([
      cla, ins, p1, p2, body.length, ...body, 0x00, // Le=00
    ]);
  }

  /// Membuka Secure Messaging pada respons kartu pintar.
  static Uint8List _unwrapSecureMessaging(Uint8List protectedResp, BacSessionKeys keys) {
    if (protectedResp.length < 2) {
      throw const NfcApduException('Panjang respons APDU kartu pintar tidak valid (< 2 byte)');
    }
    final int sw1 = protectedResp[protectedResp.length - 2];
    final int sw2 = protectedResp[protectedResp.length - 1];

    if (sw1 != 0x90 || sw2 != 0x00) {
      throw NfcApduException('Chip paspor mengembalikan status penolakan APDU', sw1, sw2);
    }

    // Inkrementasi SSC untuk verifikasi response MAC
    BacCrypto.incrementSsc(keys.ssc);

    // Parse DO'87, DO'99, DO'8E dari protected response
    int idx = 0;
    Uint8List? encData;
    Uint8List? do99;
    Uint8List? cardMac;

    while (idx < protectedResp.length - 2) {
      final tag = protectedResp[idx];
      final len = protectedResp[idx + 1];
      final val = protectedResp.sublist(idx + 2, idx + 2 + len);

      if (tag == 0x87) {
        // Enkripsi DO'87 (val[0] = padding indicator, val[1..] = ciphertext)
        encData = val.sublist(1);
      } else if (tag == 0x99) {
        do99 = protectedResp.sublist(idx, idx + 2 + len);
      } else if (tag == 0x8E) {
        cardMac = val;
      }
      idx += 2 + len;
    }

    // Bila ada data terenkripsi, dekripsi
    if (encData != null) {
      final iv = BacCrypto.des3CbcEncrypt(keys.ksEnc, Uint8List(8), keys.ssc);
      final decryptedPadded = BacCrypto.des3CbcDecrypt(keys.ksEnc, iv, encData);
      // Hapus padding method 2 (cari byte 0x80 dari belakang)
      int padIndex = decryptedPadded.length - 1;
      while (padIndex >= 0 && decryptedPadded[padIndex] == 0x00) {
        padIndex--;
      }
      if (padIndex < 0 || decryptedPadded[padIndex] != 0x80) {
        throw const NfcApduException('Padding Method 2 pada respons chip paspor rusak');
      }
      final plainData = decryptedPadded.sublist(0, padIndex);
      return Uint8List.fromList([...plainData, sw1, sw2]);
    }

    return Uint8List.fromList([sw1, sw2]);
  }

  /// Mengecek apakah dua byte terakhir adalah SW1=90 SW2=00.
  static void _assertStatusWord(Uint8List response, String operationName) {
    if (response.length < 2) {
      throw NfcApduException('$operationName gagal: panjang respons terlalu pendek');
    }
    final sw1 = response[response.length - 2];
    final sw2 = response[response.length - 1];
    if (sw1 != 0x90 || sw2 != 0x00) {
      if (sw1 == 0x69 && sw2 == 0x82) {
        throw const NfcBacFailed('Autentikasi chip paspor ditolak (Status 6982: Security status not satisfied)');
      }
      throw NfcApduException('$operationName ditolak kartu', sw1, sw2);
    }
  }

  /// Mengekstrak total panjang ASN.1 dari byte awal tag/length.
  static int _extractAsn1Length(Uint8List header) {
    if (header.length < 2) return header.length;
    final int lenByte = header[1];
    if (lenByte < 0x80) {
      return 2 + lenByte;
    } else if (lenByte == 0x81) {
      if (header.length < 3) return 256;
      return 3 + header[2];
    } else if (lenByte == 0x82) {
      if (header.length < 4) return 512;
      return 4 + ((header[2] << 8) | header[3]);
    }
    return 1024;
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('').toUpperCase();
  }
}
