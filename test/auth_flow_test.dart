import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/auth/auth_repository.dart';
import 'package:hair_app/features/auth/login_screen.dart';
import 'package:hair_app/features/auth/register_screen.dart';
import 'package:hair_app/features/auth/password_reset_screen.dart';
import 'support/profile_fakes.dart';

class AuthCredential extends Fake implements UserCredential {
  @override
  User get user => TestUser();
}

class WorkingAuth extends TestAuth {
  int registrations = 0;
  int resets = 0;
  String? resetEmail;
  Completer<void>? resetPending;
  bool failReset = false;
  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    registrations++;
    return AuthCredential();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async => AuthCredential();
  @override
  Future<void> sendPasswordResetEmail({
    required String email,
    ActionCodeSettings? actionCodeSettings,
  }) async {
    resets++;
    resetEmail = email;
    if (resetPending != null) await resetPending!.future;
    if (failReset) throw FirebaseAuthException(code: 'network-request-failed');
  }
}

void main() {
  test(
    'created account and failed profile write are distinct from failed registration',
    () async {
      final auth = WorkingAuth();
      final db = TestFirestore()..profile.failWrite = true;
      final repository = AuthRepository(auth: auth, firestore: db);
      await expectLater(
        repository.signUp(
          name: 'Alex',
          surname: 'User',
          email: 'alex@example.com',
          password: 'abcdef',
        ),
        throwsA(isA<AccountCreatedWithoutProfile>()),
      );
      expect(auth.registrations, 1);
      expect(repository.currentUser, isNotNull);
      db.profile.failWrite = false;
      await repository.updateHairProfile(
        name: 'Alex',
        surname: 'User',
        faceShape: null,
        hairTexture: null,
        hairLength: null,
      );
      expect(auth.registrations, 1);
      expect(db.profile.data['name'], 'Alex');
    },
  );

  testWidgets(
    'password reset validates, prevents double sends and allows retry',
    (tester) async {
      final auth = WorkingAuth()..failReset = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(
              AuthRepository(auth: auth, firestore: TestFirestore()),
            ),
          ],
          child: const MaterialApp(home: PasswordResetScreen()),
        ),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(auth.resets, 0);
      await tester.enterText(find.byType(TextField), 'test@example.com');
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check your internet'), findsOneWidget);
      auth.failReset = false;
      auth.resetPending = Completer<void>();
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(auth.resets, 2);
      auth.resetPending!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(auth.resetEmail, 'test@example.com');
    },
  );

  for (final register in [false, true]) {
    testWidgets(
      '${register ? 'registration' : 'login'} returns to the requesting screen',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = WorkingAuth();
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Resume scan'),
                ),
              ),
            ),
            GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
            GoRoute(
              path: '/register',
              builder: (_, _) => const RegisterScreen(),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(
                AuthRepository(auth: auth, firestore: TestFirestore()),
              ),
            ],
            child: MaterialApp.router(
              theme: AppTheme.darkTheme,
              routerConfig: router,
            ),
          ),
        );
        await tester.tap(find.text('Resume scan'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('sign-in-Apple')), findsNothing);
        expect(find.byKey(const ValueKey('sign-in-Google')), findsOneWidget);
        if (register) {
          await tester.ensureVisible(find.text('Create account'));
          await tester.tap(find.text('Create account'));
          await tester.pumpAndSettle();
          final fields = find.byType(TextFormField);
          for (var i = 0; i < 5; i++) {
            await tester.enterText(
              fields.at(i),
              ['Alex', 'User', 'test@example.com', 'abcdef', 'abcdef'][i],
            );
          }
          await tester.testTextInput.receiveAction(TextInputAction.done);
        } else {
          await tester.enterText(
            find.byType(TextField).at(0),
            'test@example.com',
          );
          await tester.enterText(find.byType(TextField).at(1), 'abcdef');
          await tester.testTextInput.receiveAction(TextInputAction.done);
        }
        await tester.pumpAndSettle();
        expect(find.text('Resume scan'), findsOneWidget);
        expect(find.byType(LoginScreen), findsNothing);
        expect(find.byType(RegisterScreen), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
