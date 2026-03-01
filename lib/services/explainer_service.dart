import 'dart:math';
import '../models/models.dart';

/// Zaman serisi verisinden Türkçe otomatik yorum üretir.
/// Python bağımlılığı yok — tamamen Dart tarafında.
class ExplainerService {
  static final ExplainerService _instance = ExplainerService._internal();
  factory ExplainerService() => _instance;
  ExplainerService._internal();

  String explain(TimeSeries ts) {
    if (ts.data.length < 2) return 'Yeterli veri yok.';

    final parts = <String>[
      _summary(ts),
      _trend(ts),
      _volatility(ts),
      _extremes(ts),
    ];

    final recent = _recentChange(ts);
    if (recent != null) parts.add(recent);

    return parts.join('\n\n');
  }

  // ── Özet: "USD/TRY bu dönemde %18 arttı, 32.10 → 38.50" ──
  String _summary(TimeSeries ts) {
    final name = ts.indicator.nameTr;
    final unit = ts.indicator.unit;
    final first = ts.data.first.value;
    final last = ts.data.last.value;
    final pct = first.abs() > 0 ? ((last - first) / first.abs()) * 100 : 0.0;
    final dir = pct >= 0 ? 'arttı ↑' : 'azaldı ↓';

    return '$name bu dönemde %${pct.abs().toStringAsFixed(1)} $dir\n'
        '${_fmt(first)} $unit → ${_fmt(last)} $unit';
  }

  // ── Trend yönü + güç ──
  String _trend(TimeSeries ts) {
    final vals = ts.data.map((d) => d.value).toList();
    final n = vals.length;

    double sx = 0, sy = 0, sxy = 0, sx2 = 0;
    for (int i = 0; i < n; i++) {
      sx += i;
      sy += vals[i];
      sxy += i * vals[i];
      sx2 += i * i;
    }
    final denom = n * sx2 - sx * sx;
    final slope = denom != 0 ? (n * sxy - sx * sy) / denom : 0.0;
    final intercept = denom != 0 ? (sy - slope * sx) / n : sy / n;
    final meanY = sy / n;

    double ssTot = 0, ssRes = 0;
    for (int i = 0; i < n; i++) {
      ssTot += (vals[i] - meanY) * (vals[i] - meanY);
      ssRes += (vals[i] - (slope * i + intercept)) *
          (vals[i] - (slope * i + intercept));
    }
    final r2 = ssTot > 0 ? 1 - (ssRes / ssTot) : 0.0;

    String desc;
    if (slope.abs() < 0.001 * meanY.abs()) {
      desc = '📊 Trend: Yatay seyrediyor (belirgin bir yön yok).';
    } else if (slope > 0) {
      desc = '📈 Trend: Yükseliş eğiliminde.';
    } else {
      desc = '📉 Trend: Düşüş eğiliminde.';
    }

    if (r2 > 0.7) {
      desc += ' Trend oldukça güçlü (R²=${r2.toStringAsFixed(2)}).';
    } else if (r2 > 0.4) {
      desc += ' Trend orta güçte (R²=${r2.toStringAsFixed(2)}).';
    } else {
      desc += ' Ancak veri dalgalı, net bir trend çizmek zor.';
    }
    return desc;
  }

  // ── Volatilite ──
  String _volatility(TimeSeries ts) {
    final vals = ts.data.map((d) => d.value).toList();
    final mean = vals.reduce((a, b) => a + b) / vals.length;
    final variance =
        vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            vals.length;
    final cv = mean != 0 ? (sqrt(variance) / mean.abs()) * 100 : 0.0;

    if (cv > 30) {
      return '⚡ Volatilite: Çok yüksek (%${cv.toStringAsFixed(0)}). '
          'Sert fiyat hareketleri gözleniyor.';
    } else if (cv > 15) {
      return '📊 Volatilite: Orta düzeyde (%${cv.toStringAsFixed(0)}). '
          'Belirgin dalgalanmalar var.';
    } else if (cv > 5) {
      return '✅ Volatilite: Düşük (%${cv.toStringAsFixed(0)}). '
          'Nispeten istikrarlı bir seyir.';
    }
    return '🔒 Volatilite: Çok düşük (%${cv.toStringAsFixed(0)}). '
        'Fiyat neredeyse sabit.';
  }

  // ── Dönem zirve / dip ──
  String _extremes(TimeSeries ts) {
    double hi = ts.data.first.value, lo = hi;
    DateTime hiD = ts.data.first.date, loD = hiD;

    for (final d in ts.data) {
      if (d.value > hi) { hi = d.value; hiD = d.date; }
      if (d.value < lo) { lo = d.value; loD = d.date; }
    }

    return '🔺 Dönem zirvesi: ${_fmt(hi)} (${_d(hiD)})\n'
        '🔻 Dönem dibi: ${_fmt(lo)} (${_d(loD)})';
  }

  // ── Son dönem ivme ──
  String? _recentChange(TimeSeries ts) {
    if (ts.data.length < 10) return null;

    final cnt = min(60, ts.data.length ~/ 3);
    final start = ts.data[ts.data.length - cnt].value;
    final end = ts.data.last.value;
    final pct = start.abs() > 0 ? ((end - start) / start.abs()) * 100 : 0.0;
    if (pct.abs() < 1) return null;

    final dir = pct > 0 ? 'yükseldi' : 'geriledi';
    final allPct = ts.data.first.value.abs() > 0
        ? ((ts.data.last.value - ts.data.first.value) /
                ts.data.first.value.abs()) *
            100
        : 0.0;

    String m = '';
    if (pct > 0 && allPct > 0 && pct > allPct / 2) {
      m = 'İvme kazanıyor, yükseliş hızlanmış görünüyor.';
    } else if (pct < 0 && allPct > 0) {
      m = 'Genel trend yukarı olsa da son dönemde geri çekilme var.';
    } else if (pct > 0 && allPct < 0) {
      m = 'Genel trend aşağı olsa da toparlanma sinyalleri var.';
    } else if (pct < 0 && allPct < 0) {
      m = 'Düşüş devam ediyor.';
    }

    return '🕐 Son dönem: Yakın dönemde '
        '%${pct.abs().toStringAsFixed(1)} $dir. $m';
  }

  String _fmt(double v) {
    if (v.abs() >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v.abs() >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(v == v.truncateToDouble() ? 0 : 2);
  }

  String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}