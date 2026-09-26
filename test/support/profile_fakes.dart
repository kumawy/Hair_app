import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser extends Fake implements User {
  @override
  String get uid => 'test-user';

  @override
  String get email => 'test@example.com';
}

class TestAuth extends Fake implements FirebaseAuth {
  TestAuth({this.signedIn = true});

  final bool signedIn;
  final user = TestUser();

  @override
  User? get currentUser => signedIn ? user : null;

  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
}

class TestFirestore extends Fake implements FirebaseFirestore {
  final profile = TestProfileDocument();
  String? collectionPath;
  String? documentPath;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    this.collectionPath = collectionPath;
    return TestUsersCollection(this);
  }
}

// Firebase references are replaced only in tests, without a Firebase backend.
// ignore: subtype_of_sealed_class
class TestUsersCollection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  TestUsersCollection(this.firestore);
  @override
  final TestFirestore firestore;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    firestore.documentPath = path;
    return firestore.profile;
  }
}

// Mutable in-memory storage allows tests to simulate writes and failures.
// ignore: subtype_of_sealed_class, must_be_immutable
class TestProfileDocument extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  Map<String, dynamic> data = {
    'name': 'Test',
    'surname': 'User',
    'faceShape': 'oval',
    'hairTexture': 'straight',
    'hairLength': 'short',
  };
  Map<String, dynamic>? lastWrite;
  SetOptions? lastOptions;
  int writes = 0;
  bool failWrite = false;
  Completer<void>? pendingWrite;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    return TestProfileSnapshot(Map.of(data));
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    writes++;
    lastWrite = Map.of(data);
    lastOptions = options;
    if (pendingWrite != null) await pendingWrite!.future;
    if (failWrite) throw StateError('Write failed');
    this.data = options?.merge == true ? {...this.data, ...data} : Map.of(data);
  }
}

// ignore: subtype_of_sealed_class
class TestProfileSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  TestProfileSnapshot(this.value);
  final Map<String, dynamic> value;

  @override
  Map<String, dynamic> data() => value;
}
