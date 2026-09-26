import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hair_app/core/local_store.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/hairstyles/providers/provider_hairstyle.dart';
import 'package:hair_app/features/hairstyles/screens/haircut_detail_screen.dart';
import 'package:hair_app/features/favorites/screens/favorites_screen.dart';
import 'package:hair_app/features/search/search_screen.dart';
import 'package:hair_app/shared/models/hairstyle.dart';
import 'package:hair_app/shared/widgets/hairstyle_card.dart';
import 'support/local_store_fake.dart';

void main() {
  void phoneSize(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 59, bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  final data =
      jsonDecode(File('assets/data/hairstyles.json').readAsStringSync()) as Map;
  final catalog = (data['hairstyles'] as List)
      .map((e) => Hairstyle.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
    testWidgets(
      'search panels hide and snap back while scrolling (${theme.brightness.name})',
      (tester) async {
        phoneSize(tester);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              hairstylesProvider.overrideWith((ref) async => catalog),
              localStoreProvider.overrideWithValue(MemoryLocalStore()),
              localOwnerProvider.overrideWithValue('guest'),
            ],
            child: MaterialApp(theme: theme, home: const SearchScreen()),
          ),
        );
        await tester.pumpAndSettle();
        final filters = find.byIcon(Icons.filter_alt_outlined);
        expect(filters.hitTestable(), findsOneWidget);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(filters.hitTestable(), findsNothing);
        expect(find.text('Short').hitTestable(), findsNothing);

        await tester.drag(find.byType(CustomScrollView), const Offset(0, 80));
        await tester.pumpAndSettle();
        expect(filters.hitTestable(), findsOneWidget);
        expect(find.text('Explore Hairstyles').hitTestable(), findsNothing);
        await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(find.text('Short').hitTestable(), findsOneWidget);
        await tester.tap(filters);
        await tester.pumpAndSettle();
        expect(find.text('Show all hairstyles'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'quick categories and modal length share state; reset clears both',
    (tester) async {
      phoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hairstylesProvider.overrideWith((ref) async => catalog),
            localStoreProvider.overrideWithValue(MemoryLocalStore()),
            localOwnerProvider.overrideWithValue('guest'),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const SearchScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Short'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Short'))
            .selected,
        isTrue,
      );
      // Face shape and hair length both have a Long chip; choose the latter.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Long').last);
      await tester.tap(find.text('Apply filters (1)'));
      await tester.pumpAndSettle();
      expect(find.byType(HairstyleCard), findsWidgets);
      expect(find.text('No hairstyles found'), findsNothing);
      await tester.tap(find.byIcon(Icons.filter_alt_outlined));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Long').last)
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Short'))
            .selected,
        isFalse,
      );
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show all hairstyles'));
      await tester.pumpAndSettle();
      expect(find.text('Textured Crop'), findsOneWidget);
      expect(find.text('French Crop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'id-only details load and favorites reflect add/remove across screens',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/hairstyle/1',
        routes: [
          GoRoute(
            path: '/hairstyle/:id',
            builder: (_, state) =>
                HairstyleDetailsRoute(id: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/favorites',
            builder: (_, _) => const FavoritesScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);
      phoneSize(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hairstylesProvider.overrideWith((ref) async => catalog),
            localStoreProvider.overrideWithValue(MemoryLocalStore()),
            localOwnerProvider.overrideWithValue('guest'),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Textured Crop'), findsOneWidget);
      await tester.tap(find.byTooltip('Save to favorites'));
      await tester.pumpAndSettle();
      router.go('/favorites');
      await tester.pumpAndSettle();
      expect(find.text('Textured Crop'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from favorites'));
      await tester.pumpAndSettle();
      expect(find.byType(HairstyleCard), findsNothing);
      router.go('/hairstyle/missing');
      await tester.pumpAndSettle();
      expect(find.text('Hairstyle not found'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
