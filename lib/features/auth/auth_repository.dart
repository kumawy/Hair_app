import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

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
        throw Exception('Не удалось создать пользователя');
      }

      // Сохраняем дополнительную информацию в Firestore
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name.trim(),
        'surname': surname.trim(),
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

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

  /// Выход из аккаунта
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Получить данные пользователя из Firestore
  Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;

    if (user == null) {
      return null;
    }

    final document = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    return document.data();
  }

  /// Обработка ошибок Firebase Authentication
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Введите корректный email';

      case 'user-not-found':
        return 'Пользователь с таким email не найден';

      case 'wrong-password':
        return 'Неверный пароль';

      case 'invalid-credential':
        return 'Неверный email или пароль';

      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован';

      case 'weak-password':
        return 'Пароль слишком слабый';

      case 'too-many-requests':
        return 'Слишком много попыток. Попробуйте позже';

      case 'network-request-failed':
        return 'Ошибка сети. Проверьте подключение к интернету';

      case 'user-disabled':
        return 'Этот аккаунт был отключен';

      default:
        return e.message ?? 'Произошла ошибка авторизации';
    }
  }
}