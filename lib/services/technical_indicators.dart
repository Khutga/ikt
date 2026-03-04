import 'dart:math';
import '../models/models.dart';

/// Hafta 4: Teknik Gösterge Hesaplayıcı
///
/// SMA, EMA, Bollinger Bantları, RSI hesaplamaları.
/// Tamamen Dart tarafında — Python bağımlılığı yok.
class TechnicalIndicators {
  static final TechnicalIndicators _instance = TechnicalIndicators._internal();
  factory TechnicalIndicators() => _instance;
  TechnicalIndicators._internal();

  /// Basit Hareketli Ortalama (SMA)
  List<double?> sma(List<double> values, int period) {
    final result = List<double?>.filled(values.length, null);
    if (values.length < period) return result;

    for (int i = period - 1; i < values.length; i++) {
      double sum = 0;
      for (int j = i - period + 1; j <= i; j++) {
        sum += values[j];
      }
      result[i] = sum / period;
    }
    return result;
  }

  /// Üstel Hareketli Ortalama (EMA)
  List<double?> ema(List<double> values, int period) {
    final result = List<double?>.filled(values.length, null);
    if (values.length < period) return result;

    // İlk EMA = SMA
    double sum = 0;
    for (int i = 0; i < period; i++) {
      sum += values[i];
    }
    result[period - 1] = sum / period;

    // k = 2 / (period + 1)
    final k = 2.0 / (period + 1);

    for (int i = period; i < values.length; i++) {
      result[i] = values[i] * k + result[i - 1]! * (1 - k);
    }
    return result;
  }

  /// Bollinger Bantları
  /// Orta bant: SMA, üst/alt: SMA ± (stdDev × multiplier)
  BollingerBands bollingerBands(
    List<double> values, {
    int period = 20,
    double multiplier = 2.0,
  }) {
    final middle = sma(values, period);
    final upper = List<double?>.filled(values.length, null);
    final lower = List<double?>.filled(values.length, null);

    for (int i = period - 1; i < values.length; i++) {
      if (middle[i] == null) continue;

      double sumSq = 0;
      for (int j = i - period + 1; j <= i; j++) {
        final diff = values[j] - middle[i]!;
        sumSq += diff * diff;
      }
      final stdDev = sqrt(sumSq / period);

      upper[i] = middle[i]! + multiplier * stdDev;
      lower[i] = middle[i]! - multiplier * stdDev;
    }

    return BollingerBands(upper: upper, middle: middle, lower: lower);
  }

  /// RSI (Göreceli Güç Endeksi)
  List<double?> rsi(List<double> values, {int period = 14}) {
    final result = List<double?>.filled(values.length, null);
    if (values.length < period + 1) return result;

    // İlk kazanç/kayıp ortalamaları
    double avgGain = 0, avgLoss = 0;
    for (int i = 1; i <= period; i++) {
      final change = values[i] - values[i - 1];
      if (change > 0) {
        avgGain += change;
      } else {
        avgLoss += change.abs();
      }
    }
    avgGain /= period;
    avgLoss /= period;

    if (avgLoss == 0) {
      result[period] = 100;
    } else {
      result[period] = 100 - (100 / (1 + avgGain / avgLoss));
    }

    // Sonraki değerler (Wilder's smoothing)
    for (int i = period + 1; i < values.length; i++) {
      final change = values[i] - values[i - 1];
      final gain = change > 0 ? change : 0.0;
      final loss = change < 0 ? change.abs() : 0.0;

      avgGain = (avgGain * (period - 1) + gain) / period;
      avgLoss = (avgLoss * (period - 1) + loss) / period;

      if (avgLoss == 0) {
        result[i] = 100;
      } else {
        result[i] = 100 - (100 / (1 + avgGain / avgLoss));
      }
    }
    return result;
  }

  /// Teknik gösterge verilerini Plotly trace formatına çevir
  List<Map<String, dynamic>> buildOverlayTraces({
    required List<DataPoint> data,
    required Set<String> activeIndicators,
    int smaPeriod = 20,
    int emaShortPeriod = 12,
    int emaLongPeriod = 26,
  }) {
    final traces = <Map<String, dynamic>>[];
    final values = data.map((d) => d.value).toList();
    final dates = data.map((d) => d.date.toIso8601String().split('T')[0]).toList();

    if (activeIndicators.contains('sma')) {
      final smaValues = sma(values, smaPeriod);
      final validDates = <String>[];
      final validVals = <double>[];
      for (int i = 0; i < smaValues.length; i++) {
        if (smaValues[i] != null) {
          validDates.add(dates[i]);
          validVals.add(smaValues[i]!);
        }
      }
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'SMA($smaPeriod)',
        'x': validDates,
        'y': validVals,
        'line': {'color': '#FFA726', 'width': 1.5, 'dash': 'dash'},
        'hovertemplate': 'SMA($smaPeriod): %{y:.2f}<extra></extra>',
      });
    }

    if (activeIndicators.contains('ema_short')) {
      final emaValues = ema(values, emaShortPeriod);
      final validDates = <String>[];
      final validVals = <double>[];
      for (int i = 0; i < emaValues.length; i++) {
        if (emaValues[i] != null) {
          validDates.add(dates[i]);
          validVals.add(emaValues[i]!);
        }
      }
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'EMA($emaShortPeriod)',
        'x': validDates,
        'y': validVals,
        'line': {'color': '#E91E63', 'width': 1.5, 'dash': 'dot'},
        'hovertemplate': 'EMA($emaShortPeriod): %{y:.2f}<extra></extra>',
      });
    }

    if (activeIndicators.contains('ema_long')) {
      final emaValues = ema(values, emaLongPeriod);
      final validDates = <String>[];
      final validVals = <double>[];
      for (int i = 0; i < emaValues.length; i++) {
        if (emaValues[i] != null) {
          validDates.add(dates[i]);
          validVals.add(emaValues[i]!);
        }
      }
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'EMA($emaLongPeriod)',
        'x': validDates,
        'y': validVals,
        'line': {'color': '#9C27B0', 'width': 1.5, 'dash': 'dot'},
        'hovertemplate': 'EMA($emaLongPeriod): %{y:.2f}<extra></extra>',
      });
    }

    if (activeIndicators.contains('bollinger')) {
      final bb = bollingerBands(values);
      final upperDates = <String>[];
      final upperVals = <double>[];
      final lowerDates = <String>[];
      final lowerVals = <double>[];

      for (int i = 0; i < bb.upper.length; i++) {
        if (bb.upper[i] != null) {
          upperDates.add(dates[i]);
          upperVals.add(bb.upper[i]!);
          lowerDates.add(dates[i]);
          lowerVals.add(bb.lower[i]!);
        }
      }

      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'BB Üst',
        'x': upperDates,
        'y': upperVals,
        'line': {'color': '#78909C', 'width': 1, 'dash': 'dot'},
        'hovertemplate': 'BB Üst: %{y:.2f}<extra></extra>',
      });
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'BB Alt',
        'x': lowerDates,
        'y': lowerVals,
        'line': {'color': '#78909C', 'width': 1, 'dash': 'dot'},
        'fill': 'tonexty',
        'fillcolor': 'rgba(120,144,156,0.08)',
        'hovertemplate': 'BB Alt: %{y:.2f}<extra></extra>',
      });
    }

    return traces;
  }

  /// Altın Kesişim / Ölüm Kesişimi sinyallerini tespit et
  List<CrossSignal> detectCrossovers(
    List<DataPoint> data, {
    int shortPeriod = 50,
    int longPeriod = 200,
  }) {
    final values = data.map((d) => d.value).toList();
    final shortSma = sma(values, shortPeriod);
    final longSma = sma(values, longPeriod);
    final signals = <CrossSignal>[];

    for (int i = 1; i < values.length; i++) {
      if (shortSma[i] == null || longSma[i] == null ||
          shortSma[i - 1] == null || longSma[i - 1] == null) {
        continue;
      }

      final prevDiff = shortSma[i - 1]! - longSma[i - 1]!;
      final currDiff = shortSma[i]! - longSma[i]!;

      if (prevDiff <= 0 && currDiff > 0) {
        signals.add(CrossSignal(
          date: data[i].date,
          type: CrossType.golden,
          price: values[i],
        ));
      } else if (prevDiff >= 0 && currDiff < 0) {
        signals.add(CrossSignal(
          date: data[i].date,
          type: CrossType.death,
          price: values[i],
        ));
      }
    }

    return signals;
  }

  /// Teknik analiz özeti üret
  String generateSummary(List<DataPoint> data, {int smaPeriod = 20}) {
    if (data.length < smaPeriod + 5) return 'Teknik analiz için yeterli veri yok.';

    final values = data.map((d) => d.value).toList();
    final lastPrice = values.last;
    final smaVals = sma(values, smaPeriod);
    final lastSma = smaVals.last;
    final rsiVals = rsi(values);
    final lastRsi = rsiVals.last;

    final parts = <String>[];

    // SMA pozisyonu
    if (lastSma != null) {
      if (lastPrice > lastSma) {
        final pctAbove = ((lastPrice - lastSma) / lastSma * 100);
        parts.add('📊 Fiyat $smaPeriod günlük SMA\'nın %${pctAbove.toStringAsFixed(1)} üzerinde → yükseliş eğilimi.');
      } else {
        final pctBelow = ((lastSma - lastPrice) / lastSma * 100);
        parts.add('📊 Fiyat $smaPeriod günlük SMA\'nın %${pctBelow.toStringAsFixed(1)} altında → düşüş eğilimi.');
      }
    }

    // RSI yorumu
    if (lastRsi != null) {
      if (lastRsi > 70) {
        parts.add('⚠️ RSI(14) = ${lastRsi.toStringAsFixed(0)} → Aşırı alım bölgesinde. Düzeltme gelebilir.');
      } else if (lastRsi < 30) {
        parts.add('📈 RSI(14) = ${lastRsi.toStringAsFixed(0)} → Aşırı satım bölgesinde. Toparlanma olası.');
      } else {
        parts.add('✅ RSI(14) = ${lastRsi.toStringAsFixed(0)} → Nötr bölgede.');
      }
    }

    // Kısa/uzun EMA kesişimi
    if (data.length > 30) {
      final ema12 = ema(values, 12);
      final ema26 = ema(values, 26);
      if (ema12.last != null && ema26.last != null) {
        if (ema12.last! > ema26.last!) {
          parts.add('🟢 EMA(12) > EMA(26) → Kısa vadeli momentum yukarı yönlü.');
        } else {
          parts.add('🔴 EMA(12) < EMA(26) → Kısa vadeli momentum aşağı yönlü.');
        }
      }
    }

    return parts.join('\n\n');
  }
}

/// Bollinger Bantları sonucu
class BollingerBands {
  final List<double?> upper;
  final List<double?> middle;
  final List<double?> lower;

  BollingerBands({
    required this.upper,
    required this.middle,
    required this.lower,
  });
}

/// Kesişim sinyali
enum CrossType { golden, death }

class CrossSignal {
  final DateTime date;
  final CrossType type;
  final double price;

  CrossSignal({required this.date, required this.type, required this.price});

  String get label =>
      type == CrossType.golden ? 'Altın Kesişim ✨' : 'Ölüm Kesişimi ☠️';

  String get dateStr =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
}