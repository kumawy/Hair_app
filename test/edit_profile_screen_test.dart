import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/auth/auth_repository.dart';
import 'package:hair_app/features/profile/screens/edit_profile_screen.dart';
import 'package:hair_app/features/profile/screens/profile_screen.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';

import 'support/profile_fakes.dart';

Finder chip(String section, String value) =>
    find.byKey(ValueKey('$section-$value'));

Future<void> openEditor(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Edit Profile'));
  await tester.tap(find.text('Edit Profile'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await tester.tap(find.text('Save changes'));
}

Future<void> pumpProfile(
  WidgetTester tester,
  TestFirestore firestore, {
  bool signedIn = true,
}) async {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/editprofile',
        builder: (_, _) => const EditProfileScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          AuthRepository(
            auth: TestAuth(signedIn: signedIn),
            firestore: firestore,
          ),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.lightTheme,
      ),
    ),
  );
  await tester.pumpAndSettle();
  await openEditor(tester);
}

void main() {
  testWidgets('loads selections, saves changes, and refreshes the profile', (
    tester,
  ) async {
    final firestore = TestFirestore();
    await pumpProfile(tester, firestore);

    expect(
      tester.widget<ChoiceChip>(chip('Face Shape', 'oval')).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(chip('Hair Texture', 'straight')).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(chip('Hair Length', 'short')).selected,
      isTrue,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'First name'),
      'Alex',
    );
    await tester.tap(chip('Face Shape', 'square'));
    await tester.tap(chip('Hair Texture', 'coily'));
    await tester.ensureVisible(chip('Hair Length', 'medium'));
    await tester.tap(chip('Hair Length', 'medium'));
    await save(tester);
    await tester.pumpAndSettle();

    expect(firestore.collectionPath, 'users');
    expect(firestore.documentPath, 'test-user');
    expect(firestore.profile.lastWrite, {
      'name': 'Alex',
      'surname': 'User',
      'faceShape': 'square',
      'hairTexture': 'coily',
      'hairLength': 'medium',
    });
    expect(firestore.profile.lastOptions?.merge, isTrue);
    expect(firestore.profile.data['name'], 'Alex');
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Square'), findsOneWidget);
    expect(find.text('Coily'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);

    await openEditor(tester);
    expect(
      tester.widget<ChoiceChip>(chip('Face Shape', 'square')).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(chip('Hair Texture', 'coily')).selected,
      isTrue,
    );
    expect(
      tester.widget<ChoiceChip>(chip('Hair Length', 'medium')).selected,
      isTrue,
    );
  });

  testWidgets('deselecting an existing value clears it in storage', (
    tester,
  ) async {
    final firestore = TestFirestore();
    await pumpProfile(tester, firestore);
    await tester.tap(chip('Face Shape', 'oval'));
    await save(tester);
    await tester.pumpAndSettle();

    expect(firestore.profile.data['faceShape'], isNull);
    expect(firestore.profile.data['hairTexture'], 'straight');
    await openEditor(tester);
    for (final shape in Shape.values) {
      expect(
        tester.widget<ChoiceChip>(chip('Face Shape', shape.name)).selected,
        isFalse,
      );
    }
  });

  testWidgets('failed save keeps edits and allows retry', (tester) async {
    final firestore = TestFirestore();
    firestore.profile.failWrite = true;
    await pumpProfile(tester, firestore);
    await tester.tap(chip('Face Shape', 'round'));
    await save(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to save profile. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(
      tester.widget<ChoiceChip>(chip('Face Shape', 'round')).selected,
      isTrue,
    );
    expect(firestore.profile.data['faceShape'], 'oval');
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNotNull,
    );

    firestore.profile.failWrite = false;
    await save(tester);
    await tester.pumpAndSettle();
    expect(firestore.profile.data['faceShape'], 'round');
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('pending save disables editing and duplicate submission', (
    tester,
  ) async {
    final firestore = TestFirestore();
    firestore.profile.pendingWrite = Completer<void>();
    await pumpProfile(tester, firestore);
    await save(tester);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
      isNull,
    );
    expect(
      tester.widget<ChoiceChip>(chip('Face Shape', 'oval')).onSelected,
      isNull,
    );
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(firestore.profile.writes, 1);

    firestore.profile.pendingWrite!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsNothing);
  });

  testWidgets('leaving without saving preserves the stored profile', (
    tester,
  ) async {
    final firestore = TestFirestore();
    await pumpProfile(tester, firestore);
    await tester.tap(chip('Face Shape', 'diamond'));
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(firestore.profile.writes, 0);
    expect(find.text('Oval'), findsOneWidget);
    await openEditor(tester);
    expect(
      tester.widget<ChoiceChip>(chip('Face Shape', 'oval')).selected,
      isTrue,
    );
  });

  testWidgets('guest cannot edit or save a profile', (tester) async {
    final firestore = TestFirestore();
    await pumpProfile(tester, firestore, signedIn: false);
    expect(find.text('Sign in to edit your profile'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Save changes'), findsNothing);
    expect(firestore.profile.writes, 0);
  });

  test('repository rejects profile writes without authentication', () async {
    final firestore = TestFirestore();
    final repository = AuthRepository(
      auth: TestAuth(signedIn: false),
      firestore: firestore,
    );
    await expectLater(
      repository.updateHairProfile(
        faceShape: Shape.oval,
        hairTexture: null,
        hairLength: null,
      ),
      throwsException,
    );
    expect(firestore.profile.writes, 0);
  });
}
