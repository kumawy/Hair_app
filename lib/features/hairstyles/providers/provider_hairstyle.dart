import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hairstyle_repository.dart';
import '../../../shared/models/hairstyle.dart';

final hairstylesProvider = FutureProvider<List<Hairstyle>>((ref) async {
  final repository = HairstyleRepository();
  return repository.loadHairstyles();
});