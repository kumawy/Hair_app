import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../hairstyles/providers/provider_hairstyle.dart';
import '../../shared/models/hairstyle.dart';
import '../../shared/models/hair_attributes.dart';
import '../../shared/widgets/hairstyle_card.dart';
import 'filter_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  int _selectedCategory = 0;
  final List<String> _categories = [
    'All',
    'Long',
    'Medium',
    'Short',
  ];

  FaceShape? _selectedFaceShape;
  HairTexture? _selectedTexture;
  HairLength? _selectedLength;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _normalize(String text) {
    return text.toLowerCase().trim();
  }

  bool _matchesSearch(Hairstyle hairstyle) {
    final query = _normalize(_searchQuery);
    if (query.isEmpty) return true;

    final queryWords = query.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

    final searchableText = [
      hairstyle.name,
      hairstyle.description,
      ...hairstyle.suitableFaceShapes.map((shape) => shape.name),
      ...hairstyle.suitableTextures.map((texture) => texture.name),
      ...hairstyle.suitableLengths.map((length) => length.name),
    ].join(' ');

    final words = _normalize(searchableText).split(RegExp(r'[\s,._\-\/]+')).where((word) => word.isNotEmpty).toList();

    return queryWords.every((queryWord) {
      return words.any((word) => word.startsWith(queryWord));
    });
  }

  bool _matchesCategory(Hairstyle hairstyle) {
    if (_selectedCategory == 0) return true;
    final selectedLength = _categories[_selectedCategory].toLowerCase();
    return hairstyle.suitableLengths.any((length) => length.name == selectedLength);
  }

  bool _matchesLength(Hairstyle hairstyle) {
    if (_selectedLength == null) return true;
    return hairstyle.suitableLengths.contains(_selectedLength);
  }

  bool _matchesFaceShape(Hairstyle hairstyle) {
    if (_selectedFaceShape == null) return true;
    return hairstyle.suitableFaceShapes.contains(_selectedFaceShape);
  }

  bool _matchesTexture(Hairstyle hairstyle) {
    if (_selectedTexture == null) return true;
    return hairstyle.suitableTextures.contains(_selectedTexture);
  }

  List<Hairstyle> _filterHairstyles(List<Hairstyle> hairstyles) {
    return hairstyles.where((hairstyle) {
      return _matchesSearch(hairstyle) &&
          _matchesCategory(hairstyle) &&
          _matchesFaceShape(hairstyle) &&
          _matchesTexture(hairstyle) &&
          _matchesLength(hairstyle);
    }).toList();
  }

  List<String> _getSuggestions(List<Hairstyle> hairstyles) {
    final query = _normalize(_searchQuery);
    if (query.isEmpty) return [];

    final suggestions = <String>{};
    for (final hairstyle in hairstyles) {
      final nameWords = hairstyle.name.split(RegExp(r'\s+'));
      final matches = nameWords.any((word) => _normalize(word).startsWith(query));
      if (matches) suggestions.add(hairstyle.name);
    }
    return suggestions.take(5).toList();
  }

  int _activeFilterCount() {
    int count = 0;
    if (_selectedCategory != 0) count++;
    if (_selectedFaceShape != null) count++;
    if (_selectedTexture != null) count++;
    if (_selectedLength != null) count++;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 0;
      _selectedFaceShape = null;
      _selectedTexture = null;
      _selectedLength = null;
    });
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _searchQuery = value),
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      hintText: 'Search hairstyles...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
                ),
                child: IconButton(
                  onPressed: () async {
                    final result = await filterScreen(
                      context,
                      faceShape: _selectedFaceShape,
                      texture: _selectedTexture,
                      length: _selectedLength,
                    );
                    if (result != null) {
                      setState(() {
                        _selectedFaceShape = result['faceShape'] as FaceShape?;
                        _selectedTexture = result['texture'] as HairTexture?;
                        _selectedLength = result['length'] as HairLength?;
                      });
                    }
                  },
                  icon: const Icon(Icons.filter_alt_outlined, size: 30),
                ),
              ),
              if (_activeFilterCount() > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_activeFilterCount()}',
                        style: TextStyle(color: theme.colorScheme.onPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategories(ThemeData theme) {
    return SizedBox(
      height: 35,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategory == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? theme.colorScheme.primary : theme.dividerColor.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  _categories[index],
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions(List<Hairstyle> hairstyles, ThemeData theme) {
    final suggestions = _getSuggestions(hairstyles);
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: suggestions.map((suggestion) {
          return ListTile(
            dense: true,
            leading: const Icon(Icons.search, size: 20),
            title: Text(suggestion),
            onTap: () {
              _searchController.text = suggestion;
              setState(() => _searchQuery = suggestion);
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SliverFillRemaining(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, color: theme.textTheme.bodySmall?.color, size: 60),
              const SizedBox(height: 15),
              Text('No hairstyles found', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Try another search or change your filters.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (_activeFilterCount() > 0)
                TextButton(
                  onPressed: _clearFilters,
                  child: Text('Clear filters', style: TextStyle(color: theme.colorScheme.secondary)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGrid(List<Hairstyle> hairstyles, ThemeData theme) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final hairstyle = hairstyles[index];
            return HairstyleCard(hairstyle: hairstyle);
          },
          childCount: hairstyles.length,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hairstylesAsync = ref.watch(hairstylesProvider);

    return Scaffold(
      body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, top: 10, bottom: 15),
                child: Text('Explore Hairstyles', style: theme.textTheme.headlineLarge),
              ),
            ),
            SliverAppBar(
              primary: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 70,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: _buildSearchBar(theme),
            ),
            if (_searchQuery.isNotEmpty)
              hairstylesAsync.when(
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                data: (data) => SliverToBoxAdapter(child: _buildSuggestions(data, theme)),
              ),
            SliverAppBar(
              primary: false,
              backgroundColor: theme.scaffoldBackgroundColor,
              elevation: 0,
              floating: true,
              snap: true,
              pinned: false,
              toolbarHeight: 50,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: _buildCategories(theme),
            ),
            hairstylesAsync.when(
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (error, stackTrace) => SliverFillRemaining(
                child: Center(child: Text('Error: $error')),
              ),
              data: (data) {
                final filteredData = _filterHairstyles(data);
                if (filteredData.isEmpty) return _buildEmptyState(theme);
                return _buildGrid(filteredData, theme);
              },
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ),
    );
  }
}
