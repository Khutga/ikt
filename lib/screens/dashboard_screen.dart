import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import 'chart_screen.dart';
import '../widgets/common_widgets.dart';
import 'comparison_screen.dart';
import '../models/models.dart';
import 'search_screen.dart';

/// Ana Dashboard Ekranı
///
/// Favoriler en üstte, ardından kategoriler.
/// Her kartta sparkline mini grafik gösterilir.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();
  final _favService = FavoritesService();

  Map<String, DashboardCategory>? _data;
  List<int> _favoriteIds = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _api.getLatestValues(),
        _favService.getFavorites(),
      ]);

      setState(() {
        _data = results[0] as Map<String, DashboardCategory>;
        _favoriteIds = results[1] as List<int>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Tüm göstergeleri düz listede topla
  List<DashboardIndicator> get _allIndicators {
    if (_data == null) return [];
    return _data!.values.expand((cat) => cat.indicators).toList();
  }

  /// Favori göstergeler
  List<DashboardIndicator> get _favoriteIndicators {
    final all = _allIndicators;
    return _favoriteIds
        .map((id) {
          try {
            return all.firstWhere((i) => i.id == id);
          } catch (_) {
            return null;
          }
        })
        .where((i) => i != null)
        .cast<DashboardIndicator>()
        .toList();
  }

  Future<void> _toggleFavorite(int id) async {
    await _favService.toggleFavorite(id);
    final newFavs = await _favService.getFavorites();
    setState(() => _favoriteIds = newFavs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFF4ECDC4),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            const Text('Makro Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparisonScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _error != null) {
      return StateWidget(
        isLoading: _isLoading,
        error: _error,
        onRetry: _loadData,
      );
    }

    if (_data == null || _data!.isEmpty) {
      return const Center(child: Text('Henüz veri yok'));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF4ECDC4),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Favoriler bölümü
          if (_favoriteIndicators.isNotEmpty) ...[
            _buildFavoritesSection(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),
          ],

          // Favori ekleme ipucu
          if (_favoriteIndicators.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF4ECDC4).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_border,
                        size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bir göstergeye uzun basarak favorilere ekleyebilirsiniz',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Kategoriler
          ..._data!.entries.map((entry) {
            final cat = entry.value;
            return _buildCategorySection(entry.key, cat);
          }),
        ],
      ),
    );
  }

  /// Favoriler bölümü — yatay kaydırma
  Widget _buildFavoritesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.star, size: 18, color: Color(0xFFFFD700)),
              const SizedBox(width: 8),
              Text(
                'Favorilerim',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const Spacer(),
              Text(
                '${_favoriteIndicators.length}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _favoriteIndicators.length,
            itemBuilder: (context, index) {
              final ind = _favoriteIndicators[index];
              return SizedBox(
                width: 170,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IndicatorCard(
                    indicator: ind,
                    isFavorite: true,
                    onTap: () => _openChart(ind.id, ind.name),
                    onLongPress: () => _toggleFavorite(ind.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(String code, DashboardCategory cat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CategoryHeader(
          title: cat.category,
          color: cat.color,
          icon: cat.icon,
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cat.indicators.length,
            itemBuilder: (context, index) {
              final ind = cat.indicators[index];
              return SizedBox(
                width: 170,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IndicatorCard(
                    indicator: ind,
                    isFavorite: _favoriteIds.contains(ind.id),
                    onTap: () => _openChart(ind.id, ind.name),
                    onLongPress: () => _toggleFavorite(ind.id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openChart(int id, String name) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChartScreen(indicatorId: id, indicatorName: name),
      ),
    );
  }
}