/// Base class for all server-related exceptions
class ServerException implements Exception {
  final String message;
  ServerException(this.message);

  @override
  String toString() => 'ServerException: $message';
}

/// Thrown when there is a network issue (e.g., no internet connection).
class NetworkException implements Exception {
  final String message;
  NetworkException(this.message);

  @override
  String toString() => 'NetworkException: $message';
}

/// Thrown when a specific wallet is not found on the blockchain/server.
class WalletNotFoundException implements Exception {
  final String message;
  WalletNotFoundException(this.message);

  @override
  String toString() => 'WalletNotFoundException: $message';
}
