import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/hairstyle.dart';
import 'favorite_button.dart';

/// Карточка причёски (картинка + название).
///
/// Раньше этот виджет был буквально скопирован 3 раза:
/// дважды в `home_screen.dart` ("Recommended for you" и "Popular
/// hairstyles") и ещё раз в `search_screen.dart` (сетка результатов
/// поиска). Теперь это один переиспользуемый виджет — размер (ширина
/// в горизонтальном списке / childAspectRatio в сетке) задаёт родитель
/// через `SizedBox`/`GridView`, а не сам виджет.
class HairstyleCard extends StatelessWidget {
  final Hairstyle hairstyle;

  /// По умолчанию переходит на экран деталей `/hairstyle/:id`.
  /// Можно переопределить своим поведением при необходимости.
  final VoidCallback? onTap;

  const HairstyleCard({super.key, required this.hairstyle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final borderRadius = BorderRadius.circular(20);

    // Border + shadow live on the outer Container (unclipped), while the
    // inner Material/InkWell clips just the image + ripple to the rounded
    // corners — otherwise clipping at the outer level would cut the shadow.
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: colorScheme.surface,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap:
              onTap ??
              () =>
                  context.push('/hairstyle/${hairstyle.id}', extra: hairstyle),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      hairstyle.imageAsset,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurface.withValues(alpha: 0.38),
                          size: 40,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: .85),
                          shape: BoxShape.circle,
                        ),
                        child: FavoriteButton(hairstyleId: hairstyle.id),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  hairstyle.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
