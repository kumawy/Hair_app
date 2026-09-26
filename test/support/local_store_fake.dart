import 'package:hair_app/core/local_store.dart';

class MemoryLocalStore extends LocalStore {
  final values = <String, String>{};
  bool failWrite = false;
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('Storage unavailable');
    values[key] = value;
  }
}
