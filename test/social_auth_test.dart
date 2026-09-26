import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/auth/auth_repository.dart';
import 'package:hair_app/features/auth/google_identity.dart';
import 'package:hair_app/features/auth/login_screen.dart';
import 'support/profile_fakes.dart';

class SocialUser extends TestUser {
  @override
  String? get displayName => 'Alex Example';
}

class SocialCredential extends Fake implements UserCredential {
  @override
  User get user => SocialUser();
}

class FakeGoogle extends Fake implements GoogleIdentity {
  String? token = 'test-id-token';
  bool signedOut = false;
  bool failCleanup = false;
  Completer<String?>? pending;
  @override
  Future<String?> idToken() async => pending != null ? pending!.future : token;
  @override
  Future<void> signOut() async {
    signedOut = true;
    if (failCleanup) throw StateError('Google unavailable');
  }
}

class SocialAuth extends TestAuth {
  AuthCredential? receivedCredential;
  FirebaseAuthException? fail;
  bool signedOut = false;
  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    receivedCredential = credential;
    if (fail != null) throw fail!;
    return SocialCredential();
  }

  @override
  Future<void> signOut() async => signedOut = true;
}

class TransactionFirestore extends TestFirestore {
  bool exists = true;
  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    final transaction = FakeTransaction(this);
    final result = await transactionHandler(transaction);
    for (final write in transaction.writes) {
      await write();
    }
    return result;
  }
}

// ignore: subtype_of_sealed_class
class NullableSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  NullableSnapshot(this.value);
  final Map<String, dynamic>? value;
  @override
  Map<String, dynamic>? data() => value;
}

class FakeTransaction extends Fake implements Transaction {
  FakeTransaction(this.db);
  final TransactionFirestore db;
  final writes = <Future<void> Function()>[];
  @override
  Future<DocumentSnapshot<T>> get<T extends Object?>(
    DocumentReference<T> reference,
  ) async =>
      NullableSnapshot(db.exists ? Map.of(db.profile.data) : null)
          as DocumentSnapshot<T>;
  @override
  Transaction set<T>(
    DocumentReference<T> reference,
    T data, [
    SetOptions? options,
  ]) {
    writes.add(() async {
      await reference.set(data, options);
      db.exists = true;
    });
    return this;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing iOS Google configuration fails before opening the native SDK',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('hair_app/social_auth_config');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => false);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await expectLater(
        NativeGoogleIdentity().idToken(),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.message,
            'message',
            contains('not configured'),
          ),
        ),
      );
    },
  );

  test(
    'Google exchanges the ID token, creates profile and preserves later edits',
    () async {
      final auth = SocialAuth();
      final db = TransactionFirestore()..exists = false;
      db.profile.data = {};
      final repository = AuthRepository(
        auth: auth,
        firestore: db,
        google: FakeGoogle(),
      );
      await repository.signInWithGoogle();
      expect(auth.receivedCredential?.providerId, 'google.com');
      expect(
        (auth.receivedCredential as OAuthCredential).idToken,
        'test-id-token',
      );
      expect(db.profile.data['name'], 'Alex');
      expect(db.profile.data['surname'], 'Example');
      expect(db.profile.data['uid'], 'test-user');
      final created = db.profile.data['createdAt'];
      db.profile.data.addAll({
        'name': 'Edited',
        'surname': '',
        'faceShape': 'diamond',
        'hairTexture': 'coily',
        'hairLength': 'long',
      });
      await repository.signInWithGoogle();
      expect(db.profile.writes, 1);
      expect(db.profile.data['name'], 'Edited');
      expect(db.profile.data['surname'], '');
      expect(db.profile.data['hairTexture'], 'coily');
      expect(db.profile.data['createdAt'], created);
    },
  );

  test(
    'Google cancellation does not authenticate; credential conflict stays an error',
    () async {
      final auth = SocialAuth();
      final google = FakeGoogle()..token = null;
      final db = TransactionFirestore();
      final repository = AuthRepository(
        auth: auth,
        firestore: db,
        google: google,
      );
      expect(await repository.signInWithGoogle(), isNull);
      expect(auth.receivedCredential, isNull);
      expect(db.profile.writes, 0);
      google.token = 'token';
      auth.fail = FirebaseAuthException(
        code: 'account-exists-with-different-credential',
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(
          isA<SocialAuthException>().having(
            (e) => e.message,
            'message',
            contains('original method'),
          ),
        ),
      );
      expect(db.profile.writes, 0);
    },
  );

  test(
    'profile failure keeps successful auth distinct; sign-out clears both sessions',
    () async {
      final db = TransactionFirestore()..profile.failWrite = true;
      final auth = SocialAuth();
      final google = FakeGoogle()..failCleanup = true;
      final repository = AuthRepository(
        auth: auth,
        firestore: db,
        google: google,
      );
      await expectLater(
        repository.signInWithGoogle(),
        throwsA(isA<SignedInWithoutProfile>()),
      );
      expect(auth.receivedCredential, isNotNull);
      await repository.signOut();
      expect(auth.signedOut, isTrue);
      expect(google.signedOut, isTrue);
    },
  );

  testWidgets(
    'Google button returns to the requesting screen after authentication',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = SocialAuth();
      final google = FakeGoogle();
      google.pending = Completer<String?>();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/login'),
                child: const Text('Saved scan draft'),
              ),
            ),
          ),
          GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              AuthRepository(
                auth: auth,
                firestore: TransactionFirestore(),
                google: google,
              ),
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.tap(find.text('Saved scan draft'));
      await tester.pumpAndSettle();
      final button = find.byKey(const ValueKey('sign-in-Google'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(find.text('Continue with Apple'), findsNothing);
      expect(auth.receivedCredential, isNull);
      google.pending!.complete('test-id-token');
      await tester.pumpAndSettle();
      expect(find.text('Saved scan draft'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
