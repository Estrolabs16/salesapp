import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/analytics_service.dart';
import '../core/services/device_service.dart';
import '../data/services/firestore_service.dart';

class GuestEmailExistsException implements Exception {
  const GuestEmailExistsException();

  @override
  String toString() =>
      'An account already exists for this email on the device.';
}

class AuthController {
  AuthController({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  static const guestModeKey = 'guest_mode';

  final FirebaseAuth _auth;

  User? get user => _auth.currentUser;

  bool get isGuest => _auth.currentUser?.isAnonymous ?? false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> signInAnonymously() async {
    await _auth.signInAnonymously();
    await _setGuestMode(true);
    await _recordDevice();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _setGuestMode(false);
    await _recordDevice();
    await AppAnalytics.logLogin();
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    if (isGuest) {
      await upgradeGuest(name: name, email: email, password: password);
      return;
    }
    final credentials = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credentials.user?.updateDisplayName(name.trim());
    await credentials.user?.sendEmailVerification();
    await _setGuestMode(false);
    await _recordDevice();
    await AppAnalytics.logSignUp();
  }

  Future<void> upgradeGuest({
    required String name,
    required String email,
    required String password,
  }) async {
    final current = _auth.currentUser;
    if (current == null || !current.isAnonymous) return;
    try {
      final credential = EmailAuthProvider.credential(
        email: email.trim(),
        password: password,
      );
      await current.linkWithCredential(credential);
      if (name.trim().isNotEmpty) {
        await current.updateDisplayName(name.trim());
      }
      try {
        await current.sendEmailVerification();
      } catch (_) {}
      await _setGuestMode(false);
      await _recordDevice();
      await AppAnalytics.logSignUp();
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use' ||
          error.code == 'credential-already-in-use') {
        throw const GuestEmailExistsException();
      }
      rethrow;
    }
  }

  Future<void> switchToExistingAccount({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _setGuestMode(false);
    await _recordDevice();
    await AppAnalytics.logLogin();
  }

  Future<void> resetPassword(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendVerificationEmail() async {
    final current = _auth.currentUser;
    if (current != null && !current.emailVerified) {
      await current.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _setGuestMode(false);
  }

  Future<void> _recordDevice() async {
    try {
      final current = _auth.currentUser;
      if (current == null) return;
      final id = await DeviceService.deviceId();
      await FirestoreService(uid: current.uid).saveDeviceMetadata(
        deviceId: id,
        isGuest: current.isAnonymous,
      );
    } catch (_) {
      // Support metadata is best-effort and must never block sign-in.
    }
  }

  Future<void> _setGuestMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(guestModeKey, value);
    } catch (_) {
      // Preference persistence is best-effort UX only.
    }
  }
}
