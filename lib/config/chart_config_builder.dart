import 'dart:math';

/// Plotly.js grafik konfigürasyonu üretici (Dart tarafında)
///
/// Python servisine bağımlılığı ortadan kaldırır.
/// Tüm grafik config'lerini yerel olarak üretir.
class ChartConfigBuilder {
  static final ChartConfigBuilder _instance = ChartConfigBuilder._internal();
  factory ChartConfigBuilder() => _instance;
  ChartConfigBuilder._internal();

  // Renk paleti
  static const List<String> colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
    '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
    '#85C1E9', '#F1948A',
  ];

  /// Ana build fonksiyonu
  Map<String, dynamic> build({
    required String chartType,
    required List<Map<String, dynamic>> seriesData,
    String title = '',
    bool overlay = false,
    bool normalize = false,
  }) {
    switch (chartType) {
      case 'area':
        return _areaChart(seriesData, title, normalize);
      case 'bar':
        return _barChart(seriesData, title);
      case 'scatter':
        return _scatterChart(seriesData, title);
      case 'line':
      default:
        return _lineChart(seriesData, title, overlay, normalize);
    }
  }

  // =========================================
  // ÇİZGİ GRAFİK
  // =========================================

  Map<String, dynamic> _lineChart(
    List<Map<String, dynamic>> seriesData,
    String title,
    bool overlay,
    bool normalize,
  ) {
    final traces = <Map<String, dynamic>>[];

    for (int i = 0; i < seriesData.length; i++) {
      final series = seriesData[i];
      final data = series['data'] as List;
      final dates = data.map((d) => d['date'].toString()).toList();
      List<double> values = data.map((d) => double.parse(d['value'].toString())).toList();

      if (normalize && values.isNotEmpty) {
        final minVal = values.reduce(min);
        final maxVal = values.reduce(max);
        final range = maxVal - minVal;
        if (range > 0) {
          values = values.map((v) => (v - minVal) / range * 100).toList();
        }
      }

      final color = colors[i % colors.length];
      final name = series['name'] ?? 'Seri ${i + 1}';
      final unit = series['unit'] ?? '';

      final trace = <String, dynamic>{
        'type': 'scatter',
        'mode': 'lines',
        'name': name,
        'x': dates,
        'y': values,
        'line': {'color': color, 'width': 2},
        'hovertemplate': '$name<br>Tarih: %{x}<br>Değer: %{y:.2f} $unit<extra></extra>',
      };

      if (overlay && i > 0) {
        trace['yaxis'] = 'y2';
      }

      traces.add(trace);
    }

    final layout = _baseLayout(title);

    if (overlay && seriesData.length > 1) {
      layout['yaxis'] = {
        'title': seriesData[0]['name'] ?? '',
        'titlefont': {'color': colors[0]},
        'tickfont': {'color': colors[0]},
        'showgrid': true,
        'gridcolor': '#f0f0f0',
      };
      layout['yaxis2'] = {
        'title': seriesData[1]['name'] ?? '',
        'titlefont': {'color': colors[1]},
        'tickfont': {'color': colors[1]},
        'overlaying': 'y',
        'side': 'right',
      };
    } else if (normalize) {
      layout['yaxis'] = {
        'title': 'Normalize Değer (0-100)',
        'showgrid': true,
        'gridcolor': '#f0f0f0',
      };
    }

    return {'data': traces, 'layout': layout, 'config': _baseConfig()};
  }

  // =========================================
  // ALAN GRAFİK
  // =========================================

  Map<String, dynamic> _areaChart(
    List<Map<String, dynamic>> seriesData,
    String title,
    bool normalize,
  ) {
    final traces = <Map<String, dynamic>>[];

    for (int i = 0; i < seriesData.length; i++) {
      final series = seriesData[i];
      final data = series['data'] as List;
      final dates = data.map((d) => d['date'].toString()).toList();
      final values = data.map((d) => double.parse(d['value'].toString())).toList();
      final color = colors[i % colors.length];

      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': series['name'] ?? 'Seri ${i + 1}',
        'x': dates,
        'y': values,
        'fill': i == 0 ? 'tozeroy' : 'tonexty',
        'line': {'color': color, 'width': 1},
        'fillcolor': '${color}4D', // %30 opacity
      });
    }

    return {'data': traces, 'layout': _baseLayout(title), 'config': _baseConfig()};
  }

  // =========================================
  // ÇUBUK GRAFİK
  // =========================================

  Map<String, dynamic> _barChart(
    List<Map<String, dynamic>> seriesData,
    String title,
  ) {
    final traces = <Map<String, dynamic>>[];

    for (int i = 0; i < seriesData.length; i++) {
      final series = seriesData[i];
      final data = series['data'] as List;
      final dates = data.map((d) => d['date'].toString()).toList();
      final values = data.map((d) => double.parse(d['value'].toString())).toList();
      final color = colors[i % colors.length];

      // Tek seri ise pozitif/negatif renklendirme
      dynamic markerColor;
      if (seriesData.length == 1) {
        markerColor = values.map((v) => v >= 0 ? '#4ECDC4' : '#FF6B6B').toList();
      } else {
        markerColor = color;
      }

      traces.add({
        'type': 'bar',
        'name': series['name'] ?? 'Seri ${i + 1}',
        'x': dates,
        'y': values,
        'marker': {'color': markerColor},
      });
    }

    final layout = _baseLayout(title);
    if (seriesData.length > 1) {
      layout['barmode'] = 'group';
    }

    return {'data': traces, 'layout': layout, 'config': _baseConfig()};
  }

  // =========================================
  // SAÇILIM GRAFİĞİ
  // =========================================

  Map<String, dynamic> _scatterChart(
    List<Map<String, dynamic>> seriesData,
    String title,
  ) {
    if (seriesData.length < 2) {
      return _lineChart(seriesData, title, false, false);
    }

    // İki seriyi tarih bazında hizala
    final dataA = seriesData[0]['data'] as List;
    final dataB = seriesData[1]['data'] as List;

    final mapA = <String, double>{};
    for (final d in dataA) {
      mapA[d['date'].toString()] = double.parse(d['value'].toString());
    }

    final xVals = <double>[];
    final yVals = <double>[];
    final dates = <String>[];

    for (final d in dataB) {
      final date = d['date'].toString();
      if (mapA.containsKey(date)) {
        xVals.add(mapA[date]!);
        yVals.add(double.parse(d['value'].toString()));
        dates.add(date);
      }
    }

    final nameA = seriesData[0]['name'] ?? 'X';
    final nameB = seriesData[1]['name'] ?? 'Y';
    final unitA = seriesData[0]['unit'] ?? '';
    final unitB = seriesData[1]['unit'] ?? '';

    final traces = <Map<String, dynamic>>[
      {
        'type': 'scatter',
        'mode': 'markers',
        'name': '$nameA vs $nameB',
        'x': xVals,
        'y': yVals,
        'text': dates,
        'marker': {
          'color': colors[0],
          'size': 6,
          'opacity': 0.7,
        },
        'hovertemplate':
            'Tarih: %{text}<br>$nameA: %{x:.2f}<br>$nameB: %{y:.2f}<extra></extra>',
      }
    ];

    // Trend çizgisi
    if (xVals.length > 2) {
      final trendLine = _linearRegression(xVals, yVals);
      final xLine = [xVals.reduce(min), xVals.reduce(max)];
      final yLine = xLine.map((x) => trendLine['slope']! * x + trendLine['intercept']!).toList();

      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'Trend',
        'x': xLine,
        'y': yLine,
        'line': {'color': '#FF6B6B', 'width': 2, 'dash': 'dash'},
      });
    }

    final layout = _baseLayout(title.isNotEmpty ? title : '$nameA vs $nameB');
    layout['xaxis'] = {
      ...(layout['xaxis'] as Map<String, dynamic>),
      'title': '$nameA ($unitA)',
    };
    layout['yaxis'] = {
      'title': '$nameB ($unitB)',
      'showgrid': true,
      'gridcolor': '#f0f0f0',
    };

    return {'data': traces, 'layout': layout, 'config': _baseConfig()};
  }

  // =========================================
  // YARDIMCI
  // =========================================

  Map<String, double> _linearRegression(List<double> x, List<double> y) {
    final n = x.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      sumX += x[i];
      sumY += y[i];
      sumXY += x[i] * y[i];
      sumX2 += x[i] * x[i];
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    return {'slope': slope, 'intercept': intercept};
  }

  Map<String, dynamic> _baseLayout(String title) {
    return {
      'title': {
        'text': title,
        'font': {'size': 16, 'color': '#333'},
        'x': 0.05,
      },
      'xaxis': {
        'title': '',
        'showgrid': true,
        'gridcolor': '#f0f0f0',
        'rangeslider': {'visible': false},
      },
      'yaxis': {
        'showgrid': true,
        'gridcolor': '#f0f0f0',
        'zeroline': true,
        'zerolinecolor': '#ddd',
      },
      'legend': {
        'orientation': 'h',
        'yanchor': 'bottom',
        'y': 1.02,
        'xanchor': 'right',
        'x': 1,
      },
      'margin': {'l': 60, 'r': 60, 't': 60, 'b': 50},
      'paper_bgcolor': 'white',
      'plot_bgcolor': 'white',
      'hovermode': 'x unified',
      'font': {'family': 'Inter, sans-serif'},
    };
  }

  Map<String, dynamic> _baseConfig() {
    return {
      'responsive': true,
      'displayModeBar': true,
      'modeBarButtonsToRemove': ['lasso2d', 'select2d', 'autoScale2d'],
      'displaylogo': false,
      'locale': 'tr',
      'scrollZoom': true,
    };
  }
}