import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

/// Hafta 5: Korelasyon Matrisi Ekranı
///
/// Birden fazla gösterge arasındaki korelasyonu
/// ısı haritası (heatmap) olarak gösterir.
class CorrelationMatrixScreen extends StatefulWidget {
  const CorrelationMatrixScreen({super.key});

  @override
  State<CorrelationMatrixScreen> createState() =>
      _CorrelationMatrixScreenState();
}

class _CorrelationMatrixScreenState extends State<CorrelationMatrixScreen> {
  final _api = ApiService();

  List<Indicator> _allIndicators = [];
  List<Indicator> _selectedIndicators = [];
  bool _loadingIndicators = true;
  bool _calculating = false;
  String? _error;
  String _period = '1y';

  // Korelasyon matrisi sonucu
  List<List<double?>>? _matrix;
  List<String>? _matrixLabels;

  @override
  void initState() {
    super.initState();
    _loadIndicators();
  }

  Future<void> _loadIndicators() async {
    try {
      final indicators = await _api.getIndicators();
      final valid = indicators.where((i) => i.lastValue != null).toList();
      setState(() {
        _allIndicators = valid;
        _loadingIndicators = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Göstergeler yüklenemedi: $e';
        _loadingIndicators = false;
      });
    }
  }

  Future<void> _calculateMatrix() async {
    if (_selectedIndicators.length < 2) return;

    setState(() {
      _calculating = true;
      _error = null;
      _matrix = null;
    });

    try {
      final n = _selectedIndicators.length;
      final dataMap = <int, List<DataPoint>>{};

      // Her gösterge için veri çek
      for (final ind in _selectedIndicators) {
        try {
          final ts = await _api.getTimeSeriesData(ind.id, period: _period);
          if (ts.data.isNotEmpty) {
            dataMap[ind.id] = ts.data;
          }
        } catch (_) {}
      }

      // Veri bulunamayanları çıkar
      final validIndicators =
          _selectedIndicators.where((i) => dataMap.containsKey(i.id)).toList();

      if (validIndicators.length < 2) {
        setState(() {
          _error = 'En az 2 gösterge için veri gerekli.';
          _calculating = false;
        });
        return;
      }

      // Korelasyon matrisini hesapla
      final matrix = List.generate(
        validIndicators.length,
        (_) => List<double?>.filled(validIndicators.length, null),
      );
      final labels =
          validIndicators.map((i) => _shortenName(i.nameTr)).toList();

      for (int i = 0; i < validIndicators.length; i++) {
        matrix[i][i] = 1.0; // Kendisiyle korelasyon = 1
        for (int j = i + 1; j < validIndicators.length; j++) {
          final corr = _pearsonCorrelation(
            dataMap[validIndicators[i].id]!,
            dataMap[validIndicators[j].id]!,
          );
          matrix[i][j] = corr;
          matrix[j][i] = corr;
        }
      }

      setState(() {
        _matrix = matrix;
        _matrixLabels = labels;
        _calculating = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Hesaplama hatası: $e';
        _calculating = false;
      });
    }
  }

  /// İki zaman serisinin Pearson korelasyonunu hesapla
  double? _pearsonCorrelation(List<DataPoint> a, List<DataPoint> b) {
    // Tarih bazlı hizalama
    final mapA = <String, double>{};
    for (final d in a) {
      mapA[d.date.toIso8601String().split('T')[0]] = d.value;
    }

    final xVals = <double>[];
    final yVals = <double>[];
    for (final d in b) {
      final key = d.date.toIso8601String().split('T')[0];
      if (mapA.containsKey(key)) {
        xVals.add(mapA[key]!);
        yVals.add(d.value);
      }
    }

    if (xVals.length < 5) return null;

    final n = xVals.length;
    double sx = 0, sy = 0, sxy = 0, sx2 = 0, sy2 = 0;
    for (int i = 0; i < n; i++) {
      sx += xVals[i];
      sy += yVals[i];
      sxy += xVals[i] * yVals[i];
      sx2 += xVals[i] * xVals[i];
      sy2 += yVals[i] * yVals[i];
    }

    final denom = sqrt((n * sx2 - sx * sx) * (n * sy2 - sy * sy));
    if (denom == 0) return null;

    return (n * sxy - sx * sy) / denom;
  }

  String _shortenName(String name) {
    if (name.length <= 15) return name;
    // Yaygın kısaltmalar
    name = name
        .replaceAll('(Döviz Alış)', '')
        .replaceAll('(Genel)', '')
        .replaceAll('(Haftalık Repo)', '')
        .replaceAll('Ağırlıklı Ortalama ', 'Ort. ')
        .replaceAll('Endeksi', 'End.')
        .replaceAll('Oranı', 'Or.');
    return name.trim().length > 18
        ? '${name.trim().substring(0, 16)}...'
        : name.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Korelasyon Matrisi'),
      ),
      body: _loadingIndicators
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF4ECDC4)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Açıklama
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16213E),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF2A2A4A)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.grid_on,
                            size: 18, color: Color(0xFF4ECDC4)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Göstergeler arasındaki korelasyonu ısı haritası olarak görüntüleyin. '
                            '2-8 arası gösterge seçin.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey[400]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Gösterge seçimi
                  _buildIndicatorSelector(),

                  const SizedBox(height: 12),

                  // Periyot
                  Row(
                    children: [
                      Text('Periyot: ',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[400])),
                      const SizedBox(width: 8),
                      ...['1y', '3y', '5y', 'max'].map((p) {
                        final isSelected = p == _period;
                        final label = {
                          '1y': '1Y',
                          '3y': '3Y',
                          '5y': '5Y',
                          'max': 'Tümü'
                        }[p]!;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected ? Colors.black : null,
                                )),
                            selected: isSelected,
                            selectedColor: const Color(0xFF4ECDC4),
                            backgroundColor: const Color(0xFF1A1A2E),
                            side: BorderSide(
                                color: isSelected
                                    ? const Color(0xFF4ECDC4)
                                    : const Color(0xFF2A2A4A)),
                            onSelected: (_) => setState(() => _period = p),
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                          ),
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Hesapla butonu
                  FilledButton.icon(
                    onPressed: _selectedIndicators.length >= 2 && !_calculating
                        ? _calculateMatrix
                        : null,
                    icon: _calculating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.calculate),
                    label: Text(_calculating
                        ? 'Hesaplanıyor...'
                        : 'Matrisi Hesapla (${_selectedIndicators.length} gösterge)'),
                  ),

                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 13)),
                    ),

                  // Heatmap
                  if (_matrix != null && _matrixLabels != null) ...[
                    const SizedBox(height: 24),
                    _buildHeatmap(),
                    const SizedBox(height: 16),
                    _buildLegend(),
                    const SizedBox(height: 16),
                    _buildInsights(),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildIndicatorSelector() {
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF2A2A4A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Gösterge Seç',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[300])),
                const Spacer(),
                Text('${_selectedIndicators.length}/8',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _allIndicators.map((ind) {
                final isSelected = _selectedIndicators.contains(ind);
                return FilterChip(
                  label: Text(
                    _shortenName(ind.nameTr),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.black : Colors.grey[300],
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF4ECDC4),
                  backgroundColor: const Color(0xFF16213E),
                  checkmarkColor: Colors.black,
                  side: BorderSide(
                    color: isSelected
                        ? const Color(0xFF4ECDC4)
                        : const Color(0xFF2A2A4A),
                  ),
                  onSelected: (val) {
                    setState(() {
                      if (val && _selectedIndicators.length < 8) {
                        _selectedIndicators.add(ind);
                      } else {
                        _selectedIndicators.remove(ind);
                      }
                      _matrix = null; // Reset
                    });
                  },
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                );
              }).toList(),
            ),
            if (_selectedIndicators.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() {
                  _selectedIndicators.clear();
                  _matrix = null;
                }),
                child: Text('Seçimi temizle',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        decoration: TextDecoration.underline)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap() {
    final n = _matrix!.length;
    final cellSize = ((MediaQuery.of(context).size.width - 100) / n)
        .clamp(40.0, 70.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Korelasyon Isı Haritası',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Üst etiketler
              Row(
                children: [
                  SizedBox(width: 80), // Sol boşluk
                  ...List.generate(n, (j) {
                    return SizedBox(
                      width: cellSize,
                      child: RotatedBox(
                        quarterTurns: -1,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            _matrixLabels![j],
                            style: TextStyle(
                                fontSize: 9, color: Colors.grey[400]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 4),
              // Matris satırları
              ...List.generate(n, (i) {
                return Row(
                  children: [
                    // Sol etiket
                    SizedBox(
                      width: 80,
                      child: Text(
                        _matrixLabels![i],
                        style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    // Hücreler
                    ...List.generate(n, (j) {
                      final val = _matrix![i][j];
                      return GestureDetector(
                        onTap: () {
                          if (val != null) {
                            _showCellDetail(i, j, val);
                          }
                        },
                        child: Container(
                          width: cellSize,
                          height: cellSize,
                          margin: const EdgeInsets.all(1),
                          decoration: BoxDecoration(
                            color: val != null
                                ? _correlationColor(val)
                                : const Color(0xFF2A2A4A),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            val != null ? val.toStringAsFixed(2) : '-',
                            style: TextStyle(
                              fontSize: cellSize > 50 ? 11 : 9,
                              fontWeight: FontWeight.w600,
                              color: val != null && val.abs() > 0.5
                                  ? Colors.white
                                  : Colors.grey[300],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('-1', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        const SizedBox(width: 4),
        ...List.generate(11, (i) {
          final val = -1.0 + i * 0.2;
          return Container(
            width: 22,
            height: 12,
            color: _correlationColor(val),
          );
        }),
        const SizedBox(width: 4),
        Text('+1', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildInsights() {
    if (_matrix == null || _matrixLabels == null) return const SizedBox();

    final n = _matrix!.length;
    final pairs = <_CorrPair>[];

    for (int i = 0; i < n; i++) {
      for (int j = i + 1; j < n; j++) {
        if (_matrix![i][j] != null) {
          pairs.add(_CorrPair(
            a: _matrixLabels![i],
            b: _matrixLabels![j],
            value: _matrix![i][j]!,
          ));
        }
      }
    }

    pairs.sort((a, b) => b.value.abs().compareTo(a.value.abs()));

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
            const Row(
              children: [
                Icon(Icons.insights, size: 18, color: Color(0xFF4ECDC4)),
                SizedBox(width: 8),
                Text('Öne Çıkan İlişkiler',
                    style:
                        TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
            ...pairs.take(5).map((p) {
              final strength = p.value.abs() >= 0.7
                  ? 'Güçlü'
                  : p.value.abs() >= 0.4
                      ? 'Orta'
                      : 'Zayıf';
              final dir = p.value > 0 ? 'pozitif' : 'negatif';
              final color = p.value > 0
                  ? const Color(0xFF4ECDC4)
                  : const Color(0xFFFF6B6B);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${p.a} ↔ ${p.b}',
                        style: const TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${p.value.toStringAsFixed(2)} ($strength $dir)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (pairs.isEmpty)
              Text('Yeterli veri yok.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Color _correlationColor(double value) {
    // -1 → kırmızı, 0 → gri, +1 → yeşil/turkuaz
    if (value >= 0) {
      return Color.lerp(
        const Color(0xFF2A2A4A),
        const Color(0xFF4ECDC4),
        value.abs(),
      )!;
    } else {
      return Color.lerp(
        const Color(0xFF2A2A4A),
        const Color(0xFFFF6B6B),
        value.abs(),
      )!;
    }
  }

  void _showCellDetail(int i, int j, double val) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          '${_matrixLabels![i]} ↔ ${_matrixLabels![j]}',
          style: const TextStyle(fontSize: 15),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                val.toStringAsFixed(4),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: _correlationColor(val),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _interpretCorrelation(val),
              style: TextStyle(fontSize: 13, color: Colors.grey[300]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  String _interpretCorrelation(double r) {
    final abs = r.abs();
    final dir = r > 0 ? 'pozitif' : 'negatif';

    if (abs >= 0.8) return 'Çok güçlü $dir ilişki. Biri artarken diğeri de ${r > 0 ? "artma" : "azalma"} eğiliminde.';
    if (abs >= 0.6) return 'Güçlü $dir ilişki. Belirgin bir birlikte hareket eğilimi var.';
    if (abs >= 0.4) return 'Orta düzey $dir ilişki. Kısmen birlikte hareket ediyorlar.';
    if (abs >= 0.2) return 'Zayıf $dir ilişki. Sınırlı bir birlikte hareket var.';
    return 'Çok zayıf veya ilişki yok. Bu iki gösterge bağımsız hareket ediyor.';
  }
}

class _CorrPair {
  final String a, b;
  final double value;
  _CorrPair({required this.a, required this.b, required this.value});
}