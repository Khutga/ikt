import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chart_screen.dart';
import '../widgets/common_widgets.dart';
import 'comparison_screen.dart';
import '../models/models.dart';
import 'search_screen.dart';

/// Ana Dashboard Ekranı
///
/// Tüm göstergelerin son değerlerini kategorize gösterir.
/// Kullanıcı bir göstergeye tıkladığında detay grafiğine gider.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService();

  Map<String, DashboardCategory>? _data;
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
      final data = await _api.getLatestValues();
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Makroekonomik Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.compare_arrows),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ComparisonScreen()),
            ),
          ),
        ],
      ),
      body: _buildBody(),
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
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: _data!.entries.map((entry) {
          final cat = entry.value;
          return _buildCategorySection(entry.key, cat);
        }).toList(),
      ),
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
          height: 110,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: cat.indicators.length,
            itemBuilder: (context, index) {
              final ind = cat.indicators[index];
              return SizedBox(
                width: 160,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: IndicatorCard(
                    indicator: ind,
                    onTap: () => _openChart(ind.id, ind.name),
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