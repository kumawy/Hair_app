import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth_repository.dart';
import '../../../shared/models/hair_attributes.dart';

/// Данные профиля пользователя, собранные из FirebaseAuth + Firestore.
class UserProfile {
  final String name;
  final String surname;
  final String email;
  final Shape? faceShape;
  final HairTexture? hairTexture;
  final HairLength? hairLength;

  const UserProfile({
    required this.name,
    required this.surname,
    required this.email,
    this.faceShape,
    this.hairTexture,
    this.hairLength,
  });

  String get fullName =>
      [name, surname].where((part) => part.isNotEmpty).join(' ');

  bool get hasHairProfile =>
      faceShape != null && hairTexture != null && hairLength != null;
}

T? _enumFromName<T extends Enum>(List<T> values, dynamic raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

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
    faceShape: _enumFromName(Shape.values, data?['faceShape']),
    hairTexture: _enumFromName(HairTexture.values, data?['hairTexture']),
    hairLength: _enumFromName(HairLength.values, data?['hairLength']),
  );
});
