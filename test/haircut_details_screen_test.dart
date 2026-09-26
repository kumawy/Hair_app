import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/core/local_store.dart';
import 'package:hair_app/core/theme.dart';
import 'package:hair_app/features/hairstyles/screens/haircut_detail_screen.dart';
import 'package:hair_app/shared/models/hairstyle.dart';

import 'support/local_store_fake.dart';

void main() {
  final catalog =
      jsonDecode(File('assets/data/hairstyles.json').readAsStringSync()) as Map;
  final hairstyle = Hairstyle.fromJson(
    Map<String, dynamic>.from(catalog['hairstyles'][0] as Map),
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'details remain usable on a small screen with large text ($brightness)',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStoreProvider.overrideWithValue(MemoryLocalStore()),
              localOwnerProvider.overrideWithValue('guest'),
            ],
            child: MaterialApp(
              theme: brightness == Brightness.dark
                  ? AppTheme.darkTheme
                  : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.4)),
                child: child!,
              ),
              home: HaircutDetailsScreen(hairstyle: hairstyle),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Save to favorites'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Remove from favorites'), findsOneWidget);
        final button = find.widgetWithText(ElevatedButton, 'Preview hairstyle');
        expect(button.hitTestable(), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Hair length'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await Scrollable.ensureVisible(
          tester.element(find.text('Hair length')),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(find.text('Hair length').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(button);
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
        expect(find.text('Your hairstyle preview'), findsOneWidget);
        expect(
          find.textContaining(RegExp('demo', caseSensitive: false)),
          findsNothing,
        );
        await tester.scrollUntilVisible(
          find.textContaining('reference photo'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.textContaining('reference photo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
