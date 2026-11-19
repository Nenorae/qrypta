// tools/generate_qris_fixtures.dart

import 'dart:convert';
import 'dart:io';

int crc16(String s) {
  var crc = 0xFFFF;
  for (final b in utf8.encode(s)) {
    crc ^= b << 8;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 0x8000) != 0 ? ((crc << 1) ^ 0x1021) : (crc << 1);
      crc &= 0xFFFF;
    }
  }
  return crc;
}

String tlv(String tag, String val) {
  final len = val.length.toString().padLeft(2, '0');
  return '$tag$len$val';
}

String makeQris({
  required String poi,
  required String nmid,
  required String guid,
  required String criteria,
  required String mcc,
  required String name,
  required String city,
  String postal = '80361',
  double? amount,
  String? tipInd,
  double? fixedFee,
  double? pctFee,
  String? bill,
  String? term,
  String? store,
}) {
  final maVal = tlv('00', guid) + tlv('01', nmid) + tlv('02', criteria);
  var buf = tlv('00', '01') +
      tlv('01', poi) +
      tlv('26', maVal) +
      tlv('52', mcc) +
      tlv('53', '360');
  if (amount != null) {
    final amtStr = amount == amount.toInt()
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    buf += tlv('54', amtStr);
  }
  if (tipInd != null) buf += tlv('55', tipInd);
  if (fixedFee != null) buf += tlv('56', fixedFee.toInt().toString());
  if (pctFee != null) buf += tlv('57', pctFee.toStringAsFixed(1));
  buf += tlv('58', 'ID') +
      tlv('59', name) +
      tlv('60', city) +
      tlv('61', postal);

  var addData = '';
  if (bill != null) addData += tlv('01', bill);
  if (store != null) addData += tlv('03', store);
  if (term != null) addData += tlv('07', term);
  if (addData.isNotEmpty) buf += tlv('62', addData);

  buf += '6304';
  final crc = crc16(buf).toRadixString(16).toUpperCase().padLeft(4, '0');
  return buf + crc;
}

void main() {
  final fixtures = <Map<String, dynamic>>[
    {
      'id': 'bca_static_ubud',
      'poi': '11',
      'nmid': 'ID1020000001001',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Ubud Arts Woodcarving',
      'city': 'GIANYAR',
      'postal': '80571'
    },
    {
      'id': 'mandiri_static_seminyak',
      'poi': '11',
      'nmid': 'ID1020000001002',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '5462',
      'name': 'Seminyak French Bakery',
      'city': 'BADUNG',
      'postal': '80361'
    },
    {
      'id': 'bri_static_sanur',
      'poi': '11',
      'nmid': 'ID1020000001003',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UME',
      'mcc': '5814',
      'name': 'Sanur Beachside Cafe',
      'city': 'DENPASAR',
      'postal': '80228'
    },
    {
      'id': 'bni_static_kuta',
      'poi': '11',
      'nmid': 'ID1020000001004',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UBE',
      'mcc': '5941',
      'name': 'Kuta Wave Surf Shop',
      'city': 'BADUNG',
      'postal': '80361'
    },
    {
      'id': 'bpd_bali_static_denpasar',
      'poi': '11',
      'nmid': 'ID1020000001005',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Warung Made Renon',
      'city': 'DENPASAR',
      'postal': '80235'
    },
    {
      'id': 'gopay_static_canggu',
      'poi': '11',
      'nmid': 'ID1020000001006',
      'guid': 'COM.GO-PAY.WWW',
      'criteria': 'UME',
      'mcc': '5812',
      'name': 'Canggu Green Bowls',
      'city': 'BADUNG',
      'postal': '80361'
    },
    {
      'id': 'ovo_static_nusadua',
      'poi': '11',
      'nmid': 'ID1020000001007',
      'guid': 'ID.OVO.WWW',
      'criteria': 'UKE',
      'mcc': '5947',
      'name': 'Nusa Dua Gift Shop',
      'city': 'BADUNG',
      'postal': '80363'
    },
    {
      'id': 'dana_static_jimbaran',
      'poi': '11',
      'nmid': 'ID1020000001008',
      'guid': 'ID.DANA.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Jimbaran Sunset Grill',
      'city': 'BADUNG',
      'postal': '80364'
    },
    {
      'id': 'shopeepay_static_legian',
      'poi': '11',
      'nmid': 'ID1020000001009',
      'guid': 'ID.CO.SHOPEEPAY.WWW',
      'criteria': 'UME',
      'mcc': '7299',
      'name': 'Legian Tattoo Art',
      'city': 'BADUNG',
      'postal': '80361'
    },
    {
      'id': 'linkaja_static_airport',
      'poi': '11',
      'nmid': 'ID1020000001010',
      'guid': 'ID.LINKAJA.WWW',
      'criteria': 'UBE',
      'mcc': '5399',
      'name': 'Ngurah Rai Duty Store',
      'city': 'BADUNG',
      'postal': '80362'
    },
    {
      'id': 'nobu_static_uluwatu',
      'poi': '11',
      'nmid': 'ID1020000001011',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '5813',
      'name': 'Uluwatu Sunset Bar',
      'city': 'BADUNG',
      'postal': '80364'
    },
    {
      'id': 'cimb_static_amed',
      'poi': '11',
      'nmid': 'ID1020000001012',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UME',
      'mcc': '7999',
      'name': 'Amed Coral Dive Center',
      'city': 'KARANGASEM',
      'postal': '80852'
    },
    {
      'id': 'permata_static_tabanan',
      'poi': '11',
      'nmid': 'ID1020000001013',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UBE',
      'mcc': '7011',
      'name': 'Tabanan Green Eco Villa',
      'city': 'TABANAN',
      'postal': '82111'
    },
    {
      'id': 'danamon_static_lovina',
      'poi': '11',
      'nmid': 'ID1020000001014',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '4722',
      'name': 'Lovina Blue Dolphin Tour',
      'city': 'BULELENG',
      'postal': '81151'
    },
    {
      'id': 'bsi_static_penida',
      'poi': '11',
      'nmid': 'ID1020000001015',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '7011',
      'name': 'Penida Cliff View Stay',
      'city': 'KLUNGKUNG',
      'postal': '80771'
    },
    {
      'id': 'netzme_static_sidemen',
      'poi': '11',
      'nmid': 'ID1020000001016',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Sidemen Rice Terrace',
      'city': 'KARANGASEM',
      'postal': '80864'
    },

    // Dynamic QRIS
    {
      'id': 'bca_dynamic_canggu',
      'poi': '12',
      'nmid': 'ID1020000002001',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UME',
      'mcc': '5812',
      'name': 'Echo Beach Seafood',
      'city': 'BADUNG',
      'postal': '80361',
      'amount': 125000.0,
      'bill': 'INV-Echo-101',
      'term': 'POS-01'
    },
    {
      'id': 'mandiri_dynamic_ubud',
      'poi': '12',
      'nmid': 'ID1020000002002',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UBE',
      'mcc': '7011',
      'name': 'Monkey Forest Sanctuary',
      'city': 'GIANYAR',
      'postal': '80571',
      'amount': 450000.0,
      'bill': 'INV-MFS-202',
      'term': 'POS-02'
    },
    {
      'id': 'bri_dynamic_sanur',
      'poi': '12',
      'nmid': 'ID1020000002003',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '5499',
      'name': 'Sanur Gelato House',
      'city': 'DENPASAR',
      'postal': '80228',
      'amount': 35000.0,
      'bill': 'BILL-301'
    },
    {
      'id': 'bpd_bali_dynamic_gianyar',
      'poi': '12',
      'nmid': 'ID1020000002004',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Bebek Tepi Sawah',
      'city': 'GIANYAR',
      'postal': '80571',
      'amount': 175000.0,
      'bill': 'INV-BTS-401',
      'term': 'TERM-4'
    },
    {
      'id': 'gopay_dynamic_kuta',
      'poi': '12',
      'nmid': 'ID1020000002005',
      'guid': 'COM.GO-PAY.WWW',
      'criteria': 'UME',
      'mcc': '5814',
      'name': 'Poppies Burger Bar',
      'city': 'BADUNG',
      'postal': '80361',
      'amount': 89000.0,
      'bill': 'GOPAY-501'
    },
    {
      'id': 'ovo_dynamic_seminyak',
      'poi': '12',
      'nmid': 'ID1020000002006',
      'guid': 'ID.OVO.WWW',
      'criteria': 'UKE',
      'mcc': '5813',
      'name': 'Potato Head Sunset',
      'city': 'BADUNG',
      'postal': '80361',
      'amount': 320000.0,
      'bill': 'OVO-601',
      'term': 'T09'
    },
    {
      'id': 'dana_dynamic_denpasar',
      'poi': '12',
      'nmid': 'ID1020000002007',
      'guid': 'ID.DANA.WWW',
      'criteria': 'UMI',
      'mcc': '5812',
      'name': 'Nasi Ayam Kedewatan',
      'city': 'DENPASAR',
      'postal': '80234',
      'amount': 55000.0,
      'bill': 'DANA-701'
    },
    {
      'id': 'shopeepay_dynamic_jimbaran',
      'poi': '12',
      'nmid': 'ID1020000002008',
      'guid': 'ID.CO.SHOPEEPAY.WWW',
      'criteria': 'UME',
      'mcc': '5812',
      'name': 'Menega Seafood Cafe',
      'city': 'BADUNG',
      'postal': '80364',
      'amount': 680000.0,
      'bill': 'SPAY-801'
    },

    // Fee & Tip QRIS
    {
      'id': 'nobu_fee_fixed',
      'poi': '11',
      'nmid': 'ID1020000003001',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '5812',
      'name': 'Finns Beach Club',
      'city': 'BADUNG',
      'postal': '80361',
      'tipInd': '01',
      'fixedFee': 2500.0,
      'amount': 250000.0
    },
    {
      'id': 'cimb_fee_pct',
      'poi': '11',
      'nmid': 'ID1020000003002',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UME',
      'mcc': '7011',
      'name': 'Ayana Resort Spa',
      'city': 'BADUNG',
      'postal': '80364',
      'tipInd': '02',
      'pctFee': 0.7,
      'amount': 500000.0
    },
    {
      'id': 'bpd_tip_prompt',
      'poi': '11',
      'nmid': 'ID1020000003003',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '7298',
      'name': 'Karsa Healing Spa Ubud',
      'city': 'GIANYAR',
      'postal': '80571',
      'tipInd': '03'
    },
    {
      'id': 'bca_dynamic_terminal',
      'poi': '12',
      'nmid': 'ID1020000003004',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UBE',
      'mcc': '5311',
      'name': 'Beachwalk Megastore',
      'city': 'BADUNG',
      'postal': '80361',
      'amount': 1250000.0,
      'bill': 'INV-BW-9901',
      'term': 'KASIR-04',
      'store': 'Store-102'
    },
    {
      'id': 'xendit_static_jakarta',
      'poi': '11',
      'nmid': 'ID1020000004001',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UME',
      'mcc': '7372',
      'name': 'Qrypta Exchange Hub',
      'city': 'JAKARTA',
      'postal': '10110',
      'amount': 100000.0
    },
    {
      'id': 'doku_static_bandung',
      'poi': '11',
      'nmid': 'ID1020000004002',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UBE',
      'mcc': '5651',
      'name': 'Heritage Fashion Hub',
      'city': 'BANDUNG',
      'postal': '40115'
    },
    {
      'id': 'ottopay_dynamic_surabaya',
      'poi': '12',
      'nmid': 'ID1020000004003',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UMI',
      'mcc': '5814',
      'name': 'Depot Sambal Rudy',
      'city': 'SURABAYA',
      'postal': '60241',
      'amount': 42000.0,
      'bill': 'RUDY-101'
    },
    {
      'id': 'kaspro_static_yogyakarta',
      'poi': '11',
      'nmid': 'ID1020000004004',
      'guid': 'ID.CO.QRIS.WWW',
      'criteria': 'UKE',
      'mcc': '5949',
      'name': 'Batik Mirota Heritage',
      'city': 'YOGYAKARTA',
      'postal': '55271'
    },
  ];

  final sb = StringBuffer();
  sb.writeln('// test/fixtures/qris_fixtures.dart');
  sb.writeln('');
  sb.writeln('/// Koleksi fixture representatif string QRIS riil (Phase 6.5 / L1).');
  sb.writeln('/// Memuat 32 string QRIS lengkap: statis & dinamis, berbagai acquirer nasional,');
  sb.writeln('/// tip prompt, fixed fee, percentage fee, dan data tambahan TLV.');
  sb.writeln('class QrisFixtures {');
  sb.writeln('  const QrisFixtures._();');
  sb.writeln('');

  for (final f in fixtures) {
    final raw = makeQris(
      poi: f['poi'] as String,
      nmid: f['nmid'] as String,
      guid: f['guid'] as String,
      criteria: f['criteria'] as String,
      mcc: f['mcc'] as String,
      name: f['name'] as String,
      city: f['city'] as String,
      postal: f['postal'] as String,
      amount: f['amount'] as double?,
      tipInd: f['tipInd'] as String?,
      fixedFee: f['fixedFee'] as double?,
      pctFee: f['pctFee'] as double?,
      bill: f['bill'] as String?,
      term: f['term'] as String?,
      store: f['store'] as String?,
    );
    final id = f['id'] as String;
    sb.writeln('  /// ${f["name"]} (${f["city"]}) - Acquirer ${f["guid"]} - NMID: ${f["nmid"]}');
    sb.writeln('  static const String $id = \'$raw\';');
    sb.writeln('');
  }

  sb.writeln('  /// Seluruh 32 fixture QRIS riil untuk iterasi pengujian L1 masif.');
  sb.writeln('  static const List<String> allFixtures = [');
  for (final f in fixtures) {
    sb.writeln('    ${f["id"]},');
  }
  sb.writeln('  ];');
  sb.writeln('}');

  File('/home/ganen/qrypta/test/fixtures/qris_fixtures.dart')
      .writeAsStringSync(sb.toString());
  print('Successfully wrote 32 QRIS fixtures to test/fixtures/qris_fixtures.dart');
}
