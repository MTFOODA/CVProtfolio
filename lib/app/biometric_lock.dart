import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth/biometric_authenticator.dart';

abstract interface class BiometricPreferenceStore {
  Future<String?> readOwner();
  Future<void> saveOwner(String? userId);
}

class DeviceBiometricPreferenceStore implements BiometricPreferenceStore {
  // This is an opt-in preference, never a password, session or biometric sample.
  static const key = 'auth.biometric.owner';

  @override
  Future<String?> readOwner() async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> saveOwner(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = userId == null
        ? await prefs.remove(key)
        : await prefs.setString(key, userId);
    if (!saved) throw StateError('Biometric preference could not be saved');
  }
}

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => DeviceBiometricAuthenticator(),
);
final biometricPreferenceStoreProvider = Provider<BiometricPreferenceStore>(
  (ref) => DeviceBiometricPreferenceStore(),
);

class BiometricLockState {
  const BiometricLockState({
    this.initialized = false,
    this.available = false,
    this.ownerId,
    this.locked = true,
    this.busy = false,
    this.foreground = true,
  });
  final bool initialized;
  final bool available;
  final String? ownerId;
  final bool locked;
  final bool busy;
  final bool foreground;
  bool get enabled => ownerId != null;

  BiometricLockState copyWith({
    bool? initialized,
    bool? available,
    String? ownerId,
    bool clearOwner = false,
    bool? locked,
    bool? busy,
    bool? foreground,
  }) => BiometricLockState(
    initialized: initialized ?? this.initialized,
    available: available ?? this.available,
    ownerId: clearOwner ? null : ownerId ?? this.ownerId,
    locked: locked ?? this.locked,
    busy: busy ?? this.busy,
    foreground: foreground ?? this.foreground,
  );
}

class BiometricLockController extends Notifier<BiometricLockState> {
  Future<void>? _loading;
  int _epoch = 0;

  @override
  BiometricLockState build() => const BiometricLockState();

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final owner = await ref
          .read(biometricPreferenceStoreProvider)
          .readOwner();
      if (ref.mounted) {
        state = state.copyWith(
          initialized: true,
          ownerId: owner,
          locked: owner != null,
        );
        // Restore the gate before probing native hardware capabilities.
        unawaited(_refreshAvailability());
      }
    } catch (_) {
      // An unreadable preference must never silently restore a protected session.
      if (ref.mounted) state = state.copyWith(initialized: true, locked: true);
    }
  }

  Future<void> _refreshAvailability() async {
    try {
      final available = await ref
          .read(biometricAuthenticatorProvider)
          .isAvailable();
      if (ref.mounted) state = state.copyWith(available: available);
    } catch (_) {
      if (ref.mounted) state = state.copyWith(available: false);
    }
  }

  Future<bool> enable(String userId, String reason) async {
    await load();
    if (state.busy || !state.foreground) return false;
    final device = ref.read(biometricAuthenticatorProvider);
    final epoch = _epoch;
    state = state.copyWith(busy: true);
    try {
      if (!await device.isAvailable()) {
        state = state.copyWith(available: false);
        return false;
      }
      if (!ref.mounted || epoch != _epoch || !state.foreground) return false;
      if (!await device.authenticate(reason) ||
          !ref.mounted ||
          epoch != _epoch ||
          !state.foreground) {
        return false;
      }
      await ref.read(biometricPreferenceStoreProvider).saveOwner(userId);
      if (!ref.mounted) return false;
      state = state.copyWith(
        ownerId: userId,
        available: true,
        locked: epoch != _epoch || !state.foreground,
      );
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> disable() async {
    _epoch++;
    await ref.read(biometricPreferenceStoreProvider).saveOwner(null);
    if (ref.mounted) state = state.copyWith(clearOwner: true, locked: false);
  }

  Future<bool> unlock(String expectedUserId, String reason) async {
    await load();
    if (!state.locked ||
        state.busy ||
        state.ownerId != expectedUserId ||
        !state.foreground) {
      return false;
    }
    final epoch = _epoch;
    state = state.copyWith(busy: true);
    try {
      final device = ref.read(biometricAuthenticatorProvider);
      if (!await device.isAvailable()) {
        state = state.copyWith(available: false);
        return false;
      }
      if (!await device.authenticate(reason) ||
          !ref.mounted ||
          epoch != _epoch ||
          !state.foreground) {
        return false;
      }
      state = state.copyWith(locked: false, available: true);
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(busy: false);
    }
  }

  Future<void> acceptFreshLogin(String userId) async {
    await load();
    if (state.ownerId != null && state.ownerId != userId) {
      await ref.read(biometricPreferenceStoreProvider).saveOwner(null);
      if (ref.mounted) state = state.copyWith(clearOwner: true);
    }
    if (ref.mounted) {
      state = state.copyWith(locked: state.enabled && !state.foreground);
    }
  }

  void onBackground() {
    _epoch++;
    state = state.copyWith(
      foreground: false,
      locked: state.enabled || state.locked,
    );
  }

  void onResume() => state = state.copyWith(foreground: true);

  void lock() {
    _epoch++;
    state = state.copyWith(locked: true);
  }
}

final biometricLockProvider =
    NotifierProvider<BiometricLockController, BiometricLockState>(
      BiometricLockController.new,
    );
