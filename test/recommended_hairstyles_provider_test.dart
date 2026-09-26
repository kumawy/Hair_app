import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hair_app/features/auth/providers/user_profile_provider.dart';
import 'package:hair_app/features/hairstyles/providers/provider_hairstyle.dart';
import 'package:hair_app/features/hairstyles/providers/recommended_hairstyles_provider.dart';
import 'package:hair_app/shared/models/hair_attributes.dart';

import 'hairstyle_recommender_test.dart' show style;

void main() {
  test(
    'no personal recommendations until complete; refreshes and clears with profile',
    () async {
      UserProfile? profile;
      final catalog = [
        style('Oval'),
        style('Diamond', face: Shape.diamond, texture: HairTexture.coily),
      ];
      final container = ProviderContainer(
        overrides: [
          userProfileProvider.overrideWith((ref) async => profile),
          hairstylesProvider.overrideWith((ref) async => catalog),
        ],
      );
      addTearDown(container.dispose);
      await container.read(userProfileProvider.future);
      await container.read(hairstylesProvider.future);
      expect(
        container.read(recommendedHairstylesProvider).requireValue,
        isEmpty,
      );
      profile = const UserProfile(
        name: '',
        surname: '',
        email: '',
        faceShape: Shape.diamond,
        hairTexture: HairTexture.coily,
        hairLength: HairLength.medium,
      );
      container.invalidate(userProfileProvider);
      await container.read(userProfileProvider.future);
      expect(
        container
            .read(recommendedHairstylesProvider)
            .requireValue
            .map((s) => s.name),
        ['Diamond'],
      );
      profile = null;
      container.invalidate(userProfileProvider);
      await container.read(userProfileProvider.future);
      expect(
        container.read(recommendedHairstylesProvider).requireValue,
        isEmpty,
      );
    },
  );
}
