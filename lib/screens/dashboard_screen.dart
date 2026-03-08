import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/favorites_service.dart';
import 'chart_screen.dart';
import '../widgets/common_widgets.dart';
import 'comparison_screen.dart';
import 'correlation_matrix_screen.dart';
import 'country_comparison_screen.dart';
import 'glossary_screen.dart';
import 'sustainability_screen.dart';
import '../models/models.dart';
import 'search_screen.dart';

/// Ana Dashboard Ekranı
///
/// v2: Ülke kıyaslama ve sürdürülebilirlik navigasyonu eklendi.
///
/// Favoriler en üstte, hızlı erişim kartları, ardından kategoriler.
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
    setState(() { _isLoading = true; _error = null; });

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
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<DashboardIndicator> get _allIndicators {
    if (_data == null) return [];
    return _data!.values.expand((cat) => cat.indicators).toList();
  }

  List<DashboardIndicator> get _favoriteIndicators {
    final all = _allIndicators;
    return _favoriteIds
        .map((id) {
          try { return all.firstWhere((i) => i.id == id); }
          catch (_) { return null; }
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
              width: 8, height: 8,
              decoration: const BoxDecoration(color: Color(0xFF4ECDC4), shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            const Text('Makro Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 22),
            tooltip: 'Ara',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (value) {
              switch (value) {
                case 'compare':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ComparisonScreen()));
                case 'matrix':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CorrelationMatrixScreen()));
                case 'country':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CountryComparisonScreen()));
                case 'sustainability':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SustainabilityScreen()));
                case 'glossary':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GlossaryScreen()));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'compare', child: Row(children: [
                Icon(Icons.compare_arrows, size: 20, color: Color(0xFF4ECDC4)),
                SizedBox(width: 10), Text('Karşılaştır'),
              ])),
              PopupMenuItem(value: 'matrix', child: Row(children: [
                Icon(Icons.grid_on, size: 20, color: Color(0xFF45B7D1)),
                SizedBox(width: 10), Text('Korelasyon Matrisi'),
              ])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'country', child: Row(children: [
                Icon(Icons.public, size: 20, color: Color(0xFF85C1E9)),
                SizedBox(width: 10), Text('Ülke Kıyaslama'),
              ])),
              PopupMenuItem(value: 'sustainability', child: Row(children: [
                Icon(Icons.eco, size: 20, color: Color(0xFF66BB6A)),
                SizedBox(width: 10), Text('Yeşil Göstergeler'),
              ])),
              PopupMenuDivider(),
              PopupMenuItem(value: 'glossary', child: Row(children: [
                Icon(Icons.menu_book, size: 20, color: Color(0xFFFFA726)),
                SizedBox(width: 10), Text('Ekonomi Sözlüğü'),
              ])),
            ],
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading || _error != null) {
      return StateWidget(isLoading: _isLoading, error: _error, onRetry: _loadData);
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
          // ★ Hızlı erişim kartları — 2 satır
          _buildQuickActionsRow1(),
          _buildQuickActionsRow2(),

          // Favoriler
          if (_favoriteIndicators.isNotEmpty) ...[
            _buildFavoritesSection(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),
          ],

          if (_favoriteIndicators.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECDC4).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF4ECDC4).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.star_border, size: 18, color: Colors.grey[400]),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Bir göstergeye uzun basarak favorilere ekleyebilirsiniz',
                          style: TextStyle(fontSize: 12, color: Colors.grey[400])),
                    ),
                  ],
                ),
              ),
            ),

          // Kategoriler
          ..._data!.entries.map((entry) {
            return _buildCategorySection(entry.key, entry.value);
          }),
        ],
      ),
    );
  }

  /// Satır 1: Analiz araçları
  Widget _buildQuickActionsRow1() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _quickActionCard(
            icon: Icons.grid_on,
            label: 'Korelasyon\nMatrisi',
            color: const Color(0xFF45B7D1),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CorrelationMatrixScreen())),
          ),
          const SizedBox(width: 8),
          _quickActionCard(
            icon: Icons.compare_arrows,
            label: 'Karşılaştır\n& Analiz',
            color: const Color(0xFF4ECDC4),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ComparisonScreen())),
          ),
          const SizedBox(width: 8),
          _quickActionCard(
            icon: Icons.menu_book,
            label: 'Ekonomi\nSözlüğü',
            color: const Color(0xFFFFA726),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const GlossaryScreen())),
          ),
        ],
      ),
    );
  }

  /// Satır 2: Uluslararası özellikler
  Widget _buildQuickActionsRow2() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Row(
        children: [
          _quickActionCard(
            icon: Icons.public,
            label: 'Ülke\nKıyaslama',
            color: const Color(0xFF85C1E9),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CountryComparisonScreen())),
          ),
          const SizedBox(width: 8),
          _quickActionCard(
            icon: Icons.eco,
            label: 'Yeşil\nGöstergeler',
            color: const Color(0xFF66BB6A),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SustainabilityScreen())),
          ),
          const SizedBox(width: 8),
          // Boşluk veya gelecek özellik
          Expanded(child: Container()),
        ],
      ),
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 6),
                Text(label,
                    style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

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
              Text('Favorilerim',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${_favoriteIndicators.length}',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
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
                    indicator: ind, isFavorite: true,
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
        CategoryHeader(title: cat.category, color: cat.color, icon: cat.icon),
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
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ChartScreen(indicatorId: id, indicatorName: name)));
  }
}