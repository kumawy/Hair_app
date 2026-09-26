import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'google_identity.dart';
import '../../shared/models/hair_attributes.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleIdentity _google;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleIdentity? google,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _google = google ?? NativeGoogleIdentity();

  /// Текущий авторизованный пользователь
  User? get currentUser => _auth.currentUser;

  /// Отслеживание состояния авторизации
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Регистрация нового пользователя
  Future<UserCredential> signUp({
    required String name,
    required String surname,
    required String email,
    required String password,
  }) async {
    try {
      // Создаем аккаунт в Firebase Authentication
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw Exception('Could not create the account. Please try again.');
      }

      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name.trim(),
          'surname': surname.trim(),
          'email': user.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // Authentication succeeded. Do not invite the user to register again.
        throw const AccountCreatedWithoutProfile();
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  /// Вход существующего пользователя
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthError(e));
    }
  }

  Future<UserCredential?> signInWithGoogle() => _socialSignIn(() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(
        GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'}),
      );
    }
    final token = await _google.idToken();
    if (token == null) return null;
    return _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: token),
    );
  });

  Future<UserCredential?> _socialSignIn(
    Future<UserCredential?> Function() authenticate,
  ) async {
    try {
      final credential = await authenticate();
      final user = credential?.user;
      if (user == null) return null;
      try {
        await _ensureSocialProfile(user);
      } catch (_) {
        throw const SignedInWithoutProfile();
      }
      return credential;
    } on FirebaseAuthException catch (error) {
      if (const {
        'canceled',
        'cancelled',
        'web-context-canceled',
        'popup-closed-by-user',
        'cancelled-popup-request',
      }.contains(error.code)) {
        return null;
      }
      if (error.code == 'account-exists-with-different-credential' ||
          error.code == 'credential-already-in-use') {
        throw const SocialAuthException(
          'An account already uses this email. Sign in with its original method.',
        );
      }
      if (const {
        'operation-not-allowed',
        'invalid-oauth-client-id',
        'unauthorized-domain',
        'invalid-configuration',
      }.contains(error.code)) {
        throw const SocialAuthException(
          'This sign-in method is not configured yet. Please use email for now.',
        );
      }
      throw SocialAuthException(_handleAuthError(error));
    }
  }

  Future<void> _ensureSocialProfile(User user) async {
    final document = _firestore.collection('users').doc(user.uid);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(document);
      final data = snapshot.data();
      final displayName = user.displayName?.trim() ?? '';
      final parts = displayName.isEmpty
          ? <String>[]
          : displayName.split(RegExp(r'\s+'));
      final fields = <String, dynamic>{
        if (data == null) ...{
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
        if (data?['email'] == null && user.email != null) 'email': user.email,
        // Existing names, including intentionally empty names, are user-owned.
        if (data?['name'] == null && parts.isNotEmpty) 'name': parts.first,
        if (data?['surname'] == null && parts.length > 1)
          'surname': parts.skip(1).join(' '),
      };
      if (fields.isNotEmpty) {
        transaction.set(document, fields, SetOptions(merge: true));
      }
    });
  }

  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found') return;
      throw Exception(_handleAuthError(error));
    }
  }

  /// Выход из аккаунта
  Future<void> signOut() async {
    await _auth.signOut();
    // Firebase is the session authority; Google cleanup must not turn a
    // successful sign-out into an error or revoke the user's consent.
    if (!kIsWeb) {
      try {
        await _google.signOut();
      } catch (_) {
        /* No Firebase session remains. */
      }
    }
  }

  /// Получить данные пользователя из Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final document = await _firestore.collection('users').doc(user.uid).get();

    return document.data();
  }

  /// Сохранить все параметры волос и лица. null очищает выбранный параметр.
  Future<void> updateHairProfile({
    required Shape? faceShape,
    required HairTexture? hairTexture,
    required HairLength? hairLength,
    String? name,
    String? surname,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Sign in to save your profile');

    await _firestore.collection('users').doc(user.uid).set({
      if (name != null) 'name': name.trim(),
      if (surname != null) 'surname': surname.trim(),
      'faceShape': faceShape?.name,
      'hairTexture': hairTexture?.name,
      'hairLength': hairLength?.name,
    }, SetOptions(merge: true));
  }

  /// Обработка ошибок Firebase Authentication
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address';

      case 'user-not-found':
        return 'Invalid email or password';

      case 'wrong-password':
        return 'Invalid email or password';

      case 'invalid-credential':
        return 'Invalid email or password';

      case 'email-already-in-use':
        return 'This email is already registered. Sign in or reset your password.';

      case 'weak-password':
        return 'Choose a stronger password';

      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      case 'user-disabled':
        return 'This account has been disabled';

      default:
        return 'Could not complete authentication. Please try again.';
    }
  }
}

class AccountCreatedWithoutProfile implements Exception {
  const AccountCreatedWithoutProfile();
  @override
  String toString() =>
      'Your account was created, but profile details could not be saved. Complete them in Edit Profile.';
}

class SignedInWithoutProfile implements Exception {
  const SignedInWithoutProfile();
  @override
  String toString() =>
      'You are signed in, but profile details could not be saved. Complete them in Edit Profile.';
}
