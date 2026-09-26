import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract interface class GoogleIdentity {
  Future<String?> idToken();
  Future<void> signOut();
}

class NativeGoogleIdentity implements GoogleIdentity {
  static Future<void>? _initialization;
  static const _config = MethodChannel('hair_app/social_auth_config');

  Future<void> _initialize() async {
    // GoogleSignIn is process-wide and must only be initialized once.
    _initialization ??= _configure();
    try {
      await _initialization;
    } catch (_) {
      _initialization = null;
      rethrow;
    }
  }

  Future<void> _configure() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      throw const SocialAuthException(
        'Use the Android or iPhone app for Google sign-in.',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // The native Google SDK can raise an Objective-C exception when its
      // client ID or callback URL is missing. Check before opening its UI.
      final ready = await _config.invokeMethod<bool>('googleConfigured');
      if (ready != true) {
        throw const SocialAuthException(
          'Google sign-in is not configured in this build yet. Please use email for now.',
        );
      }
    }
    await GoogleSignIn.instance.initialize();
  }

  @override
  Future<String?> idToken() async {
    try {
      await _initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw const SocialAuthException(
          'Google could not verify this account. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) return null;
      if (error.code == GoogleSignInExceptionCode.clientConfigurationError ||
          error.code == GoogleSignInExceptionCode.providerConfigurationError) {
        throw const SocialAuthException(
          'Google sign-in is not configured in this build yet. Please use email for now.',
        );
      }
      throw const SocialAuthException(
        'Could not sign in with Google. Check your connection and try again.',
      );
    } on PlatformException {
      throw const SocialAuthException(
        'Google sign-in is unavailable. Please try again or use email.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    if (_initialization == null) return;
    await _initialization;
    await GoogleSignIn.instance.signOut();
  }
}

class SocialAuthException implements Exception {
  const SocialAuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
