import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/core/local_store.dart';
import 'package:hair_app/core/theme.dart';
import 'support/local_store_fake.dart';

void main() {
  test(
    'favorites survive recreation, serialize writes and isolate accounts',
    () async {
      final store = MemoryLocalStore();
      ProviderContainer open(String owner) => ProviderContainer(
        overrides: [
          localStoreProvider.overrideWithValue(store),
          localOwnerProvider.overrideWithValue(owner),
        ],
      );
      final guest = open('guest');
      final collection = guest.read(favoritesProvider.notifier);
      await Future.wait([
        collection.update(
          (items) => [
            ...items,
            {'id': '1'},
          ],
        ),
        collection.update(
          (items) => [
            ...items,
            {'id': '2'},
          ],
        ),
      ]);
      expect(guest.read(favoritesProvider).requireValue.map((e) => e['id']), [
        '1',
        '2',
      ]);
      guest.dispose();
      final reopened = open('guest');
      final account = open('user-1');
      addTearDown(reopened.dispose);
      addTearDown(account.dispose);
      await reopened.read(favoritesProvider.notifier).update((items) => items);
      await account.read(favoritesProvider.notifier).update((items) => items);
      expect(reopened.read(favoritesProvider).requireValue, hasLength(2));
      expect(account.read(favoritesProvider).requireValue, isEmpty);
      store.failWrite = true;
      await expectLater(
        reopened.read(favoritesProvider.notifier).update((_) => []),
        throwsStateError,
      );
      expect(reopened.read(favoritesProvider).requireValue, hasLength(2));
      store.failWrite = false;
      await reopened
          .read(favoritesProvider.notifier)
          .update((items) => items.where((e) => e['id'] != '1').toList());
      expect(reopened.read(favoritesProvider).requireValue.single['id'], '2');
    },
  );

  test(
    'theme is restored and failed writes retain the last saved choice',
    () async {
      final store = MemoryLocalStore();
      final first = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      await first.read(themeProvider.notifier).setMode(ThemeMode.light);
      first.dispose();
      final second = ProviderContainer(
        overrides: [localStoreProvider.overrideWithValue(store)],
      );
      addTearDown(second.dispose);
      second.read(themeProvider);
      await Future<void>.delayed(Duration.zero);
      expect(second.read(themeProvider), ThemeMode.light);
      store.failWrite = true;
      await expectLater(
        second.read(themeProvider.notifier).setMode(ThemeMode.dark),
        throwsStateError,
      );
      expect(second.read(themeProvider), ThemeMode.light);
    },
  );
}
