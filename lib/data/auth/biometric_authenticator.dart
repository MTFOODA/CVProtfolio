import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  bool get usesWindowsHello;
  Future<bool> isAvailable();
  Future<bool> authenticate(String reason);
}

class DeviceBiometricAuthenticator implements BiometricAuthenticator {
  final LocalAuthentication _auth = LocalAuthentication();

  @override
  bool get usesWindowsHello =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  Future<bool> isAvailable() async {
    if (kIsWeb ||
        !{
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
          TargetPlatform.windows,
        }.contains(defaultTargetPlatform)) {
      return false;
    }
    try {
      if (usesWindowsHello) return await _auth.isDeviceSupported();
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) => _auth.authenticate(
    localizedReason: reason,
    biometricOnly: !usesWindowsHello,
    persistAcrossBackgrounding: false,
  );
}
