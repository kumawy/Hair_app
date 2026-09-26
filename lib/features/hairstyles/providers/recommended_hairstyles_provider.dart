import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/hairstyle.dart';
import '../../auth/providers/user_profile_provider.dart';
import '../../face_scanner/models/face_analysis.dart';
import '../services/hairstyle_recommender.dart';
import 'provider_hairstyle.dart';

final recommendedHairstylesProvider = Provider<AsyncValue<List<Hairstyle>>>((
  ref,
) {
  final catalog = ref.watch(hairstylesProvider);
  final profile = ref.watch(userProfileProvider).valueOrNull;
  if (profile == null || !profile.hasHairProfile) return const AsyncData([]);
  return catalog.whenData(
    (styles) => compatibleRecommendations(
      styles,
      HairProfileSelection(
        faceShape: profile.faceShape!,
        texture: profile.hairTexture!,
        length: profile.hairLength!,
      ),
    ).map((item) => item.hairstyle).toList(),
  );
});
