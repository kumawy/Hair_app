import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../shared/models/hairstyle.dart';

class HairstyleRepository {
  Future<List<Hairstyle>> loadHairstyles() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/hairstyles.json');
      final jsonData = jsonDecode(jsonString) as Map<String, dynamic>;
      final hairstyleList = jsonData['hairstyles'] as List<dynamic>;

      return hairstyleList
          .map((json) => Hairstyle.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load hairstyles: $e');
    }
  }
}