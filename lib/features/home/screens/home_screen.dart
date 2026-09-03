import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../hairstyles/providers/provider_hairstyle.dart';
import 'package:go_router/go_router.dart';

class Home extends ConsumerWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.sizeOf(context);
    final hairstylesAsync = ref.watch(hairstylesProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
          flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.6, 1],),),),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () {
              context.push('/loginscreen');
            },
            splashColor: colorScheme.onSurface.withValues(alpha: 0.1),
            highlightColor: colorScheme.onSurface.withValues(alpha: 0.05),
            icon: const Icon(Icons.account_circle_rounded, size: 40),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body:
       ListView(
          padding: const EdgeInsets.only(top: 100, bottom: 120),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, Aslan",
                    style: textTheme.headlineLarge,
                  ),
                  Text(
                    "Ready for a new look?",
                    style: textTheme.bodyMedium?.copyWith(fontSize: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Center(
              child: Container(
                height: size.height / 7,
                width: size.width / 1.1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Analyze My Hair",
                              style: textTheme.titleLarge?.copyWith(
                                color: colorScheme.onPrimary,
                              ),
                            ),
                            Text(
                              "Get personalized hairstyle recommendations",
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onPrimary.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: IconButton(
                        onPressed: () {
                          context.go('/FaceScanner');
                        },
                        splashColor: colorScheme.onPrimary.withValues(alpha: 0.1),
                        highlightColor: colorScheme.onPrimary.withValues(alpha: 0.05),
                        icon: Icon(
                          Icons.arrow_circle_right_outlined,
                          color: colorScheme.onPrimary,
                          size: 50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Recommended for you",
                    style: textTheme.titleLarge,
                  ),
                  Text(
                    "See all",
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: size.height / 4,
              child: hairstylesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => const Center(
                    child: Text('Failed to load hairstyles'),
                  ),
                  data: (data) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: size.width / 2.5,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  child: Image.asset(
                                    data[index].imageAsset,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: colorScheme.onSurface.withValues(alpha: 0.38),
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  data[index].name,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Popular hairstyles",
                    style: textTheme.titleLarge,
                  ),
                  Text(
                    "See all",
                    style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: size.height / 4,
              child: hairstylesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stackTrace) => const Center(
                    child: Text('Failed to load hairstyles'),
                  ),
                  data: (data) {
                    return ListView.builder(
                      padding: const EdgeInsets.only(left: 20),
                      scrollDirection: Axis.horizontal,
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: size.width / 2.5,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  child: Image.asset(
                                    data[index].imageAsset,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: colorScheme.onSurface.withValues(alpha: 0.38),
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Text(
                                  data[index].name,
                                  style: textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
              ),
            ),
          ],
        ),

    );
  }
}
