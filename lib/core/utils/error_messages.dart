import 'package:firebase_auth/firebase_auth.dart';

String friendlyError(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Use a stronger password with at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network unavailable. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email and password sign-in is not enabled for this project.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
  if (error is FirebaseException) {
    if (error.code == 'permission-denied') {
      return 'You do not have permission to do that.';
    }
    if (error.code == 'unavailable' || error.code == 'network-request-failed') {
      return 'Network unavailable. Check your connection and try again.';
    }
    return error.message ?? 'Something went wrong. Please try again.';
  }
  final text = error.toString();
  if (text.startsWith('Exception: ')) {
    return text.substring(11);
  }
  return text;
}
