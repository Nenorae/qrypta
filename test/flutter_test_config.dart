// test/flutter_test_config.dart

import 'dart:async';
import 'package:qrypta/src/core/config/app_config.dart';

/// Test executable harness that initializes verified testing defaults for bare `flutter test` executions.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (AppConfig.rpcUrl.isEmpty) {
    AppConfig.setTestOverrides(
      rpcUrl: 'http://10.0.2.2:8545',
      ezsignUrl: 'http://10.0.2.2:3000/api/v1',
      bapendaTreasuryAddress: '0x3565E871c841A8cE127B0e05Eb512a865F93845B',
    );
  }
  await testMain();
}
