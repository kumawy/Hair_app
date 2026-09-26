import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/auth/auth_repository.dart';
import 'package:hair_app/features/face_scanner/models/face_analysis.dart';
import 'package:hair_app/features/face_scanner/models/face_mesh.dart';
import 'package:hair_app/features/face_scanner/screens/face_scanner_screen.dart';
import 'package:hair_app/features/face_scanner/services/face_analysis_service.dart';
import 'package:hair_app/features/face_scanner/models/scan_photo.dart';
import 'package:hair_app/features/hairstyles/providers/provider_hairstyle.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';

import 'support/profile_fakes.dart';
import 'support/local_store_fake.dart';
import 'package:hair_app/core/local_store.dart';
import 'package:hair_app/features/auth/providers/user_profile_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hair_app/features/profile/screens/analysis_history_screen.dart';

class TestPhotoPicker {
  final photo = ScanPhoto(
    bytes: base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
    ),
    name: 'test.png',
  );
}

class TestAnalysisService implements FaceAnalysisService {
  bool fail = false;
  int calls = 0;
  Completer<FaceAnalysis>? pending;
  @override
  Future<FaceAnalysis> analyze(
    Uint8List photo, {
    required String filename,
    ValueChanged<FaceMesh>? onMesh,
  }) async {
    calls++;
    if (fail) {
      throw const FaceAnalysisException(
        'No face found. Use a closer, front-facing photo.',
      );
    }
    return pending?.future ??
        const FaceAnalysis(
          suggestedShape: Shape.oval,
          scores: {Shape.oval: .55, Shape.round: .45},
        );
  }
}

Finder choice(String title, String name) =>
    find.byKey(ValueKey('scan-$title-$name'));
Future<void> tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tap(tester, find.text(text));

Future<void> pumpScanner(
  WidgetTester tester,
  TestFirestore firestore, {
  bool signedIn = true,
  TestAnalysisService? service,
  MemoryLocalStore? localStore,
  Stream<User?>? authStream,
  bool profileFails = false,
}) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(localStore ?? MemoryLocalStore()),
        if (authStream != null)
          authStateChangesProvider.overrideWith((ref) => authStream),
        if (profileFails)
          userProfileProvider.overrideWith(
            (ref) async => throw StateError('Offline'),
          ),
        authRepositoryProvider.overrideWithValue(
          AuthRepository(
            auth: TestAuth(signedIn: signedIn),
            firestore: firestore,
          ),
        ),
        scannerCameraProvider.overrideWithValue(
          (onCaptured, onManual, onClose) => Scaffold(
            body: Column(
              children: [
                const Text('Live camera'),
                TextButton(
                  onPressed: () => onCaptured(TestPhotoPicker().photo),
                  child: const Text('Take photo'),
                ),
                TextButton(
                  onPressed: onManual,
                  child: const Text('Choose face shape manually'),
                ),
              ],
            ),
          ),
        ),
        faceAnalysisServiceProvider.overrideWithValue(
          service ?? TestAnalysisService(),
        ),
        hairstylesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const FaceScannerScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> manualHairStep(WidgetTester tester) async {
  await tapText(tester, 'Choose face shape manually');
  await tap(tester, choice('Face shape', 'diamond'));
  await tapText(tester, 'Confirm shape');
}

void main() {
  testWidgets(
    'guest result survives sign-in and records readable metadata without photos',
    (tester) async {
      final store = MemoryLocalStore();
      final auth = StreamController<User?>();
      addTearDown(auth.close);
      await pumpScanner(
        tester,
        TestFirestore(),
        signedIn: false,
        localStore: store,
        authStream: auth.stream,
      );
      auth.add(null);
      await tester.pumpAndSettle();
      await manualHairStep(tester);
      await tap(tester, choice('Hair texture', 'coily'));
      await tap(tester, choice('Current length', 'long'));
      await tapText(tester, 'See recommendations');
      final entry =
          (jsonDecode(store.values['analyses.guest']!) as List).single as Map;
      expect(entry.keys.toSet(), {
        'id',
        'createdAt',
        'faceShape',
        'hairTexture',
        'hairLength',
        'source',
      });
      expect(entry['faceShape'], 'diamond');
      auth.add(TestUser());
      await tester.pumpAndSettle();
      expect(find.text('Diamond face'), findsOneWidget);
      expect(find.text('Coily hair'), findsOneWidget);
      expect(find.text('Save to profile'), findsOneWidget);
      auth.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Live camera'), findsOneWidget);
      // Reopen history with the same durable store; exercise the reader too.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStoreProvider.overrideWithValue(store),
            localOwnerProvider.overrideWithValue('guest'),
            hairstylesProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(home: AnalysisHistoryScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Diamond · Coily · Long'), findsOneWidget);
      expect(find.text('Unavailable result'), findsNothing);
    },
  );

  testWidgets('profile loading failure still allows manual hair parameters', (
    tester,
  ) async {
    await pumpScanner(tester, TestFirestore(), profileFails: true);
    await manualHairStep(tester);
    expect(find.textContaining('You can choose them below'), findsOneWidget);
    await tap(tester, choice('Hair texture', 'curly'));
    await tap(tester, choice('Current length', 'short'));
    await tapText(tester, 'See recommendations');
    expect(find.text('Curly hair'), findsOneWidget);
    expect(find.text('Short length'), findsOneWidget);
  });

  testWidgets(
    'requires confirmation, prefills hair and saves only on explicit action',
    (tester) async {
      final firestore = TestFirestore();
      await pumpScanner(tester, firestore);
      expect(find.text('Choose photo'), findsNothing);
      expect(find.byIcon(Icons.photo_library_outlined), findsNothing);
      await tapText(
        tester,
        find.text('Retake photo').evaluate().isNotEmpty
            ? 'Retake photo'
            : 'Take photo',
      );
      await tapText(tester, 'Analyze photo');
      expect(find.text('Suggested shape: Oval'), findsOneWidget);
      expect(find.textContaining('The result is unclear'), findsOneWidget);
      expect(firestore.profile.writes, 0);
      await tap(tester, choice('Face shape', 'diamond'));
      await tapText(tester, 'Confirm shape');
      expect(
        tester.widget<ChoiceChip>(choice('Hair texture', 'straight')).selected,
        isTrue,
      );
      expect(
        tester.widget<ChoiceChip>(choice('Current length', 'short')).selected,
        isTrue,
      );
      await tapText(tester, 'See recommendations');
      expect(find.text('Diamond face'), findsOneWidget);
      expect(firestore.profile.writes, 0);
      await tapText(tester, 'Save to profile');
      expect(firestore.profile.lastWrite, {
        'faceShape': 'diamond',
        'hairTexture': 'straight',
        'hairLength': 'short',
      });
      expect(find.text('Saved to profile'), findsOneWidget);
      await tapText(tester, 'Edit parameters');
      await tapText(tester, 'Back to face shape');
      await tapText(tester, 'Try another photo');
      await tapText(
        tester,
        find.text('Retake photo').evaluate().isNotEmpty
            ? 'Retake photo'
            : 'Take photo',
      );
      await tapText(tester, 'Analyze photo');
      await tapText(tester, 'Confirm shape');
      await tapText(tester, 'See recommendations');
      expect(find.text('Oval face'), findsOneWidget);
      expect(find.text('Saved to profile'), findsNothing);
      expect(find.text('Save to profile'), findsOneWidget);
      expect(firestore.profile.data['faceShape'], 'diamond');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing parameters must be completed, guest can finish without saving',
    (tester) async {
      final firestore = TestFirestore();
      await pumpScanner(tester, firestore, signedIn: false);
      await manualHairStep(tester);
      final next = find.widgetWithText(ElevatedButton, 'See recommendations');
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await tap(tester, choice('Hair texture', 'coily'));
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await tap(tester, choice('Current length', 'long'));
      await tapText(tester, 'See recommendations');
      expect(find.text('Coily hair'), findsOneWidget);
      expect(find.text('Save to profile'), findsNothing);
      expect(firestore.profile.writes, 0);
      await tapText(tester, 'Start a new scan');
      expect(find.text('Live camera'), findsOneWidget);
      expect(find.text('Diamond face'), findsNothing);
    },
  );

  testWidgets('failed analysis retains photo and supports retry', (
    tester,
  ) async {
    final service = TestAnalysisService()..fail = true;
    await pumpScanner(tester, TestFirestore(), service: service);
    await tapText(
      tester,
      find.text('Retake photo').evaluate().isNotEmpty
          ? 'Retake photo'
          : 'Take photo',
    );
    await tapText(tester, 'Analyze photo');
    expect(find.textContaining('No face found'), findsOneWidget);
    expect(find.text('Confirm your face shape'), findsNothing);
    service.fail = false;
    await tapText(tester, 'Analyze photo');
    expect(service.calls, 2);
    expect(find.text('Confirm your face shape'), findsOneWidget);
  });

  testWidgets('failed save retains choices and can be retried', (tester) async {
    final firestore = TestFirestore();
    firestore.profile.failWrite = true;
    await pumpScanner(tester, firestore);
    await manualHairStep(tester);
    await tapText(tester, 'See recommendations');
    await tapText(tester, 'Save to profile');
    expect(find.textContaining('Could not save your profile'), findsOneWidget);
    expect(find.text('Diamond face'), findsOneWidget);
    expect(firestore.profile.data['faceShape'], 'oval');
    firestore.profile.failWrite = false;
    await tapText(tester, 'Save to profile');
    expect(firestore.profile.writes, 2);
    expect(firestore.profile.data['faceShape'], 'diamond');
  });

  testWidgets(
    'pending analysis disables duplicate submissions and survives disposal',
    (tester) async {
      final service = TestAnalysisService()
        ..pending = Completer<FaceAnalysis>();
      await pumpScanner(tester, TestFirestore(), service: service);
      await tapText(
        tester,
        find.text('Retake photo').evaluate().isNotEmpty
            ? 'Retake photo'
            : 'Take photo',
      );
      await tester.ensureVisible(find.text('Analyze photo'));
      await tester.tap(find.text('Analyze photo'));
      await tester.pump();
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(service.calls, 1);
      await tester.pumpWidget(const SizedBox());
      service.pending!.complete(
        const FaceAnalysis(suggestedShape: Shape.oval, scores: {Shape.oval: 1}),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
