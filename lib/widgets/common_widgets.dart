import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../models/models.dart';
import 'dart:math';

/// Periyot seçici
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
                  color: isSelected ? Colors.black : null,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF4ECDC4),
              backgroundColor: const Color(0xFF1A1A2E),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF4ECDC4)
                    : const Color(0xFF2A2A4A),
              ),
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

/// Gösterge kartı — sparkline dahil
class IndicatorCard extends StatelessWidget {
  final DashboardIndicator indicator;
  final bool isFavorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const IndicatorCard({
    super.key,
    required this.indicator,
    this.isFavorite = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Değişim yönüne göre renk
    final isUp = (indicator.changePercent ?? 0) >= 0;
    final changeColor = isUp
        ? const Color(0xFF4ECDC4)  // Turkuaz
        : const Color(0xFFFF6B6B); // Kırmızı
    final sparkColor = indicator.sparkline.isNotEmpty
        ? changeColor
        : const Color(0xFF4ECDC4);

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isFavorite
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF2A2A4A),
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst satır: isim + favori ikonu
              Row(
                children: [
                  Expanded(
                    child: Text(
                      indicator.name,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isFavorite)
                    const Icon(Icons.star, size: 14, color: Color(0xFFFFD700)),
                ],
              ),

              const SizedBox(height: 4),

              // Değer + değişim
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      indicator.value != null
                          ? _formatNumber(indicator.value!)
                          : '-',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    indicator.unit,
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),

              // Değişim yüzdesi
              if (indicator.changePercent != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${isUp ? '+' : ''}${indicator.changePercent!.toStringAsFixed(2)}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: changeColor,
                    ),
                  ),
                ),

              const Spacer(),

              // Sparkline mini grafik
              if (indicator.sparkline.isNotEmpty)
                SizedBox(
                  height: 28,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _SparklinePainter(
                      values: indicator.sparkline,
                      color: sparkColor,
                    ),
                  ),
                )
              else if (indicator.date != null)
                Text(
                  indicator.date!,
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  maxLines: 1,
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

/// Sparkline mini grafik painter
class _SparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparklinePainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minVal = values.reduce(min);
    final maxVal = values.reduce(max);
    final range = maxVal - minVal;
    if (range == 0) return;

    final dx = size.width / (values.length - 1);

    // Çizgi
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minVal) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, linePaint);

    // Gradient dolgu
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.2), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Son nokta (dot)
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final lastX = (values.length - 1) * dx;
    final lastY = size.height - ((values.last - minVal) / range * size.height);
    canvas.drawCircle(Offset(lastX, lastY), 2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Kategori başlık
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
    Color accentColor = const Color(0xFF4ECDC4);
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

/// Yükleniyor / Hata / Boş durum
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
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF4ECDC4),
          ),
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
              const Icon(Icons.error_outline, size: 48,
                  color: Color(0xFFFF6B6B)),
              const SizedBox(height: 12),
              Text(
                error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[400]),
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
      coeffColor = coefficient > 0
          ? const Color(0xFF4ECDC4)
          : const Color(0xFFFF6B6B);
    } else if (coefficient.abs() >= 0.3) {
      coeffColor = const Color(0xFFFFA726);
    } else {
      coeffColor = Colors.grey;
    }

    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, size: 20,
                    color: Color(0xFF4ECDC4)),
                const SizedBox(width: 8),
                const Text(
                  'Korelasyon Analizi',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                if (isSignificant)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Anlamlı',
                      style: TextStyle(
                          fontSize: 11, color: Color(0xFF4ECDC4)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF16213E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                interpretation['summary_tr'] ?? '',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            _detailRow('Veri noktası', '${result['data_points'] ?? '-'}'),
            _detailRow('p-değeri', '${pearson['p_value'] ?? '-'}'),
            _detailRow('Spearman',
                '${(result['spearman']?['coefficient'] ?? '-')}'),
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
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          Text(value,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}