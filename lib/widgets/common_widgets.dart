import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';

/// Periyot seçici - 1A, 3A, 1Y, 5Y, 10Y, Tümü
class PeriodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const PeriodSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AppConfig.periods.map((p) {
          final isSelected = p['value'] == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(
                p['label']!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : null,
                ),
              ),
              selected: isSelected,
              selectedColor: Theme.of(context).colorScheme.primary,
              onSelected: (_) => onChanged(p['value']!),
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Grafik tipi seçici
class ChartTypeSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const ChartTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final iconMap = {
      'line': Icons.show_chart,
      'area': Icons.area_chart,
      'bar': Icons.bar_chart,
      'scatter': Icons.scatter_plot,
    };

    return SegmentedButton<String>(
      segments: AppConfig.chartTypes.map((t) {
        return ButtonSegment(
          value: t['value']!,
          icon: Icon(iconMap[t['value']] ?? Icons.show_chart, size: 18),
          label: Text(t['label']!, style: const TextStyle(fontSize: 12)),
        );
      }).toList(),
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

/// Gösterge kartı - Dashboard'da kullanılır
class IndicatorCard extends StatelessWidget {
  final DashboardIndicator indicator;
  final VoidCallback? onTap;

  const IndicatorCard({
    super.key,
    required this.indicator,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                indicator.name,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Text(
                indicator.value != null
                    ? '${_formatNumber(indicator.value!)} ${indicator.unit}'
                    : 'Veri yok',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (indicator.date != null)
                Text(
                  indicator.date!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatNumber(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 2);
  }
}

/// Kategori başlık widget'ı
class CategoryHeader extends StatelessWidget {
  final String title;
  final String? color;
  final String? icon;
  final VoidCallback? onSeeAll;

  const CategoryHeader({
    super.key,
    required this.title,
    this.color,
    this.icon,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    Color accentColor = Colors.blue;
    if (color != null && color!.startsWith('#')) {
      try {
        accentColor = Color(int.parse(color!.replaceFirst('#', '0xFF')));
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Tümü', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

/// Yükleniyor / Hata / Boş durum widget'ları
class StateWidget extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final VoidCallback? onRetry;

  const StateWidget({
    super.key,
    this.isLoading = false,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tekrar Dene'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Korelasyon sonuç kartı
class CorrelationResultCard extends StatelessWidget {
  final Map<String, dynamic> result;

  const CorrelationResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final pearson = result['pearson'] ?? {};
    final interpretation = result['interpretation'] ?? {};
    final coefficient = (pearson['coefficient'] as num?)?.toDouble() ?? 0;
    final isSignificant = pearson['significant'] == true;

    Color coeffColor;
    if (coefficient.abs() >= 0.6) {
      coeffColor = coefficient > 0 ? Colors.green : Colors.red;
    } else if (coefficient.abs() >= 0.3) {
      coeffColor = Colors.orange;
    } else {
      coeffColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Korelasyon Analizi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                if (isSignificant)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Anlamlı',
                      style: TextStyle(fontSize: 11, color: Colors.green),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Katsayı gösterimi
            Center(
              child: Column(
                children: [
                  Text(
                    coefficient.toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: coeffColor,
                    ),
                  ),
                  Text(
                    'Pearson Korelasyon Katsayısı',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Yorum
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                interpretation['summary_tr'] ?? '',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            // Detay satırları
            _detailRow('Veri noktası', '${result['data_points'] ?? '-'}'),
            _detailRow('p-değeri', '${pearson['p_value'] ?? '-'}'),
            _detailRow(
              'Spearman',
              '${(result['spearman']?['coefficient'] ?? '-')}',
            ),
            if ((result['lag_days'] ?? 0) > 0)
              _detailRow('Gecikme', '${result['lag_days']} gün'),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}