import 'dart:developer';
import 'package:qrypta/src/features/authentication/domain/repositories/authentication_repository.dart';

class GetChecksumAddressUseCase {
  final AuthenticationRepository repository;

  GetChecksumAddressUseCase(this.repository);

  Future<String> call(String privateKey) async {
    log('Executing GetChecksumAddressUseCase', name: 'GetChecksumAddressUseCase');
    try {
      final result = await repository.getChecksumAddress(privateKey);
      log('GetChecksumAddressUseCase successful: $result', name: 'GetChecksumAddressUseCase');
      return result;
    } catch (e, s) {
      log('Error in GetChecksumAddressUseCase', name: 'GetChecksumAddressUseCase', error: e, stackTrace: s);
      rethrow;
    }
  }
}
