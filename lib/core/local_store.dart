import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/auth/providers/user_profile_provider.dart';

class LocalStore {
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  Future<String?> read(String key) => _preferences.getString(key);
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);
}

final localStoreProvider = Provider<LocalStore>((ref) => LocalStore());
final localOwnerProvider = Provider<String>(
  (ref) => ref.watch(authStateChangesProvider).valueOrNull?.uid ?? 'guest',
);

/// Device-local metadata, separated by account. No photos are stored here.
class LocalCollection
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  LocalCollection(this.store, this.key) : super(const AsyncLoading()) {
    _loaded = _load();
  }
  final LocalStore store;
  final String key;
  late final Future<void> _loaded;
  Future<void> _writes = Future.value();

  Future<void> _load() async {
    try {
      final raw = await store.read(key);
      final data = raw == null ? <dynamic>[] : jsonDecode(raw) as List;
      final entries = data
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) state = AsyncData(entries);
    } catch (error, stack) {
      if (mounted) state = AsyncError(error, stack);
    }
  }

  Future<void> update(
    List<Map<String, dynamic>> Function(List<Map<String, dynamic>>) change,
  ) {
    final operation = _writes.then((_) async {
      await _loaded;
      if (!mounted) return;
      final current = state.requireValue;
      final next = change(List.of(current));
      await store.write(key, jsonEncode(next));
      if (mounted) state = AsyncData(next);
    });
    _writes = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}

final favoritesProvider =
    StateNotifierProvider<
      LocalCollection,
      AsyncValue<List<Map<String, dynamic>>>
    >(
      (ref) => LocalCollection(
        ref.watch(localStoreProvider),
        'favorites.${ref.watch(localOwnerProvider)}',
      ),
    );
final analysisHistoryProvider =
    StateNotifierProvider<
      LocalCollection,
      AsyncValue<List<Map<String, dynamic>>>
    >(
      (ref) => LocalCollection(
        ref.watch(localStoreProvider),
        'analyses.${ref.watch(localOwnerProvider)}',
      ),
    );
