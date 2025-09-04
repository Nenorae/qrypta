import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthenticationService {
  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false, // Allows PIN/Pattern/Passcode
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (e) {
      // Handle exceptions (e.g., user cancels, no hardware)
      print('Authentication error: $e');
      return false;
    }
  }
}