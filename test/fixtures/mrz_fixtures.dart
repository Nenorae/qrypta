// test/fixtures/mrz_fixtures.dart

import 'package:qrypta/src/core/utils/mrz_parser.dart';

class MrzFixtures {
  static MrzParseResult demoJamesWilson() {
    return MrzParser.parse(
      'P<GBRWILSON<<JAMES<<<<<<<<<<<<<<<<<<<<<<<<<<',
      '7249187895GBR8805120M3203189<<<<<<<<<<<<<<02',
    );
  }
}
