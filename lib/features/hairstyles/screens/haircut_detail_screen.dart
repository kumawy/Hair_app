import 'package:flutter/material.dart';
import 'package:hair_app/shared/models/hairstyle.dart';
import 'package:go_router/go_router.dart';

class HaircutDetailsScreen extends StatelessWidget {
  final Hairstyle hairstyle;

  const HaircutDetailsScreen({
    super.key,
    required this.hairstyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                    child: Image.asset(
                      hairstyle.imageAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                pinned: true,
                expandedHeight: 400,
                // РЕШЕНИЕ: Обернули в UnconstrainedBox и добавили отступ слева
                leading: UnconstrainedBox(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: _CircleArroundButton(
                      child: IconButton(
                        padding: EdgeInsets.zero, // Сбрасываем внутренний отступ
                        constraints: const BoxConstraints(), // Убираем дефолтный размер кнопки
                        onPressed: () => context.pop(),
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          color: colorScheme.onSurface,
                          size: 18, // 18-19 компенсирует визуальную массу по сравнению с сердцем
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  // Добавили отступ справа для симметрии
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _CircleArroundButton(
                      child: IconButton(
                        padding: EdgeInsets.zero, // Сбрасываем внутренний отступ
                        constraints: const BoxConstraints(), // Убираем дефолтный размер кнопки
                        onPressed: () {
                          // TODO: favorite
                        },
                        icon: Icon(
                          Icons.favorite_border,
                          color: colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                  child:Padding(
                    padding: EdgeInsetsGeometry.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Listcontainer(title: "Face Shape", items: hairstyle.suitableFaceShapes.map((texture) => texture.name).toList()),
                        SizedBox(height: 20),
                        _Listcontainer(title: "Texture", items: hairstyle.suitableTextures.map((texture) => texture.name).toList())
                      ],
                    )
                  )
              ),
            ],
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    // TODO: book / select
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.onPrimary, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Generate',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Виджет круга сделан StatelessWidget, так как в нем нет динамического состояния (State)
class _CircleArroundButton extends StatelessWidget {
  const _CircleArroundButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: Center(child: child),
    );
  }
}

class _Listcontainer extends StatelessWidget {
  final String title;
  final List<String> items; // Принимаем просто список строк

  const _Listcontainer({
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final itemName = items[index];

              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      itemName,
                      style: TextStyle(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
