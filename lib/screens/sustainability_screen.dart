import 'package:flutter/material.dart';
import '../services/international_api_service.dart';
import '../models/international_models.dart';
import '../widgets/common_widgets.dart';

/// Yeşil & Sürdürülebilirlik Ekranı
///
/// Türkiye'nin çevresel göstergelerini diğer ülkelerle karşılaştırır.
/// CO₂ emisyonu, yenilenebilir enerji payı, orman alanı vb.
class SustainabilityScreen extends StatefulWidget {
  const SustainabilityScreen({super.key});

  @override
  State<SustainabilityScreen> createState() => _SustainabilityScreenState();
}

class _SustainabilityScreenState extends State<SustainabilityScreen> {
  final _intlApi = InternationalApiService();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _dashboardData;

  // Karşılaştırılacak ülke grupları
  List<String> _selectedGroup = ['TUR', 'USA', 'DEU', 'CHN', 'BRA'];

  static const _groups = {
    'Varsayılan': ['TUR', 'USA', 'DEU', 'CHN', 'BRA'],
    'G7 vs TR': ['TUR', 'USA', 'DEU', 'GBR', 'FRA', 'JPN'],
    'BRICS+ vs TR': ['TUR', 'BRA', 'RUS', 'IND', 'CHN', 'ZAF'],
    'Komşu & Bölge': ['TUR', 'GRC', 'EGY', 'SAU', 'RUS'],
  };

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await _intlApi.getSustainabilityDashboard(
        countryCodes: _selectedGroup,
      );
      setState(() { _dashboardData = data; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.eco, size: 20, color: Color(0xFF66BB6A)),
            SizedBox(width: 8),
            Text('Yeşil & Sürdürülebilirlik'),
          ],
        ),
      ),
      body: _isLoading
          ? const StateWidget(isLoading: true)
          : _error != null
              ? StateWidget(error: _error, onRetry: _loadData)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final indicators = _dashboardData?['indicators'] as List? ?? [];

    // PHP bazen boş objeyi [] (List) olarak döner, güvenli parse
    Map<String, dynamic> rankings = {};
    final rawRankings = _dashboardData?['turkey_rankings'];
    if (rawRankings is Map<String, dynamic>) {
      rankings = rawRankings;
    } else if (rawRankings is Map) {
      rankings = rawRankings.map((k, v) => MapEntry(k.toString(), v));
    }

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF66BB6A),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          // Açıklama
          _buildIntro(),
          const SizedBox(height: 16),

          // Ülke grubu seçici
          _buildGroupSelector(),
          const SizedBox(height: 20),

          // Türkiye özet kartı
          if (rankings.isNotEmpty) _buildTurkeySummary(rankings, indicators),
          const SizedBox(height: 16),

          // Her gösterge için kıyaslama kartı
          ...indicators.asMap().entries.map((entry) {
            final idx = entry.key;
            final ind = entry.value as Map<String, dynamic>;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildIndicatorCard(idx, ind),
            );
          }),

          const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF66BB6A).withOpacity(0.08),
            const Color(0xFF26A69A).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.eco, size: 18, color: Color(0xFF66BB6A)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Türkiye\'nin Yeşil Karnesi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF66BB6A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'CO₂ emisyonu, yenilenebilir enerji kullanımı, orman alanı ve '
            'enerji tüketimi gibi çevresel göstergelerde Türkiye\'nin '
            'dünya ülkeleriyle karşılaştırması.',
            style: TextStyle(fontSize: 12, color: Colors.grey[400], height: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            'Kaynak: Dünya Bankası • Veriler yıllık',
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _groups.entries.map((entry) {
          final isSelected = _selectedGroup == entry.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(entry.key,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.black : null,
                  )),
              selected: isSelected,
              selectedColor: const Color(0xFF66BB6A),
              backgroundColor: const Color(0xFF1A1A2E),
              side: BorderSide(
                color: isSelected ? const Color(0xFF66BB6A) : const Color(0xFF2A2A4A),
              ),
              onSelected: (_) {
                setState(() => _selectedGroup = entry.value);
                _loadData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTurkeySummary(Map<String, dynamic> rankings, List indicators) {
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: const Color(0xFFFF6B6B).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('🇹🇷', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text('Türkiye Özet',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rankings.entries.map((entry) {
                final data = entry.value as Map<String, dynamic>;
                final rank = data['rank'];
                final total = data['total'];
                if (rank == null || total == null) return const SizedBox();

                // Gösterge adını bul
                final idx = int.tryParse(entry.key) ?? 0;
                String indName = '';
                if (idx < indicators.length) {
                  indName = (indicators[idx] as Map<String, dynamic>)['name_tr'] ?? '';
                }

                final isGood = rank <= total / 2;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isGood ? const Color(0xFF66BB6A) : const Color(0xFFFF7043))
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '#$rank/$total',
                        style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold,
                          color: isGood ? const Color(0xFF66BB6A) : const Color(0xFFFF7043),
                        ),
                      ),
                      Text(
                        _shortenName(indName),
                        style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorCard(int idx, Map<String, dynamic> indicator) {
    final nameTr = indicator['name_tr'] ?? '';
    final unit = indicator['unit'] ?? '';
    final countries = indicator['countries'] as Map<String, dynamic>? ?? {};

    // Değerlere göre sırala
    final sorted = countries.entries.toList()
      ..sort((a, b) {
        final va = double.tryParse((a.value as Map)['value']?.toString() ?? '0') ?? 0;
        final vb = double.tryParse((b.value as Map)['value']?.toString() ?? '0') ?? 0;
        return vb.compareTo(va);
      });

    // Max değer (bar ölçekleme için)
    double maxVal = 0;
    for (final entry in sorted) {
      final v = double.tryParse((entry.value as Map)['value']?.toString() ?? '0') ?? 0;
      if (v.abs() > maxVal) maxVal = v.abs();
    }

    // Gösterge ikonu
    final icon = _indicatorIcon(nameTr);

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF66BB6A)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(nameTr,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 12),
            ...sorted.map((entry) {
              final iso = entry.key;
              final data = entry.value as Map<String, dynamic>;
              final value = double.tryParse(data['value']?.toString() ?? '0') ?? 0;
              final flag = data['flag'] ?? '';
              final name = data['name'] ?? iso;
              final isTurkey = iso == 'TUR';
              final barWidth = maxVal > 0 ? (value.abs() / maxVal).clamp(0.0, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(width: 24, child: Text(flag, style: const TextStyle(fontSize: 14))),
                    SizedBox(
                      width: 70,
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isTurkey ? FontWeight.bold : FontWeight.normal,
                          color: isTurkey ? const Color(0xFFFF6B6B) : Colors.grey[400],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 16,
                            decoration: BoxDecoration(
                              color: const Color(0xFF16213E),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth,
                            child: Container(
                              height: 16,
                              decoration: BoxDecoration(
                                color: isTurkey
                                    ? const Color(0xFFFF6B6B).withOpacity(0.5)
                                    : const Color(0xFF66BB6A).withOpacity(0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 60,
                      child: Text(
                        _formatValue(value),
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTurkey ? const Color(0xFFFF6B6B) : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatValue(double v) {
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 1);
  }

  String _shortenName(String name) {
    return name.length > 20 ? '${name.substring(0, 18)}...' : name;
  }

  IconData _indicatorIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('co₂') || lower.contains('co2') || lower.contains('emisyon')) {
      return Icons.cloud;
    }
    if (lower.contains('yenilenebilir') || lower.contains('renewable')) {
      return Icons.solar_power;
    }
    if (lower.contains('orman') || lower.contains('forest')) return Icons.park;
    if (lower.contains('enerji') || lower.contains('energy')) return Icons.bolt;
    return Icons.eco;
  }
}