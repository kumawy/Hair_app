import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_repository.dart';

/// Данные профиля пользователя, собранные из FirebaseAuth + Firestore.
class UserProfile {
  final String name;
  final String surname;
  final String email;

  const UserProfile({
    required this.name,
    required this.surname,
    required this.email,
  });

  String get fullName =>
      [name, surname].where((part) => part.isNotEmpty).join(' ');
}

/// Стрим состояния авторизации Firebase. Эмитит новое значение при
/// каждом входе/выходе из аккаунта — на него можно подписаться из
/// любого места приложения, чтобы реагировать на логин/логаут "живьём".
final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Профиль текущего пользователя.
///
/// Зависит от [authStateChangesProvider], поэтому автоматически
/// пересчитывается при входе/выходе из аккаунта — в отличие от старого
/// `UserRepository`, который был singleton'ом с ручным `fetchAndSaveUserData()`,
/// вызываемым один раз в `initState()`. Экраны, использующие
/// `ref.watch(userProfileProvider)`, перестраиваются сами, даже если их
/// widget-состояние держится живым внутри `StatefulShellRoute.indexedStack`.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authStateChangesProvider);
  final user = authState.value;

  if (user == null) {
    return null;
  }

  final repository = ref.read(authRepositoryProvider);
  final data = await repository.getUserData();

  return UserProfile(
    name: data?['name'] as String? ?? '',
    surname: data?['surname'] as String? ?? '',
    email: user.email ?? '',
  );
});
