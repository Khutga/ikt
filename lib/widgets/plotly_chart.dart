import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// PlotlyChart - Plotly.js ile interaktif grafik widget'ı
///
/// Python mikroservisinden gelen Plotly config JSON'ını
/// WebView içinde render eder.
///
/// Kullanım:
/// ```dart
/// PlotlyChart(
///   plotlyConfig: configFromPython,
///   height: 400,
///   darkMode: false,
/// )
/// ```
class PlotlyChart extends StatefulWidget {
  /// Plotly.js config: {data, layout, config}
  final Map<String, dynamic> plotlyConfig;

  /// Grafik yüksekliği
  final double height;

  /// Karanlık mod
  final bool darkMode;

  /// Yüklenme callback'i
  final VoidCallback? onLoaded;

  const PlotlyChart({
    super.key,
    required this.plotlyConfig,
    this.height = 400,
    this.darkMode = false,
    this.onLoaded,
  });

  @override
  State<PlotlyChart> createState() => _PlotlyChartState();
}

class _PlotlyChartState extends State<PlotlyChart> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.darkMode ? Colors.grey[900]! : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _renderChart();
            setState(() => _isLoading = false);
            widget.onLoaded?.call();
          },
        ),
      )
      ..loadHtmlString(_buildHtml());
  }

  @override
  void didUpdateWidget(PlotlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Config değiştiğinde grafiği yeniden çiz
    if (oldWidget.plotlyConfig != widget.plotlyConfig) {
      _renderChart();
    }
  }

  /// Plotly.js'e config gönderip grafiği çizdir
  void _renderChart() {
    final configJson = jsonEncode(widget.plotlyConfig);

    // Dark mode layout override
    String layoutOverride = '';
    if (widget.darkMode) {
      layoutOverride = '''
        config.layout.paper_bgcolor = '#1a1a2e';
        config.layout.plot_bgcolor = '#16213e';
        config.layout.font = {color: '#e0e0e0', family: 'Inter, sans-serif'};
        if (config.layout.xaxis) {
          config.layout.xaxis.gridcolor = '#2a2a4a';
          config.layout.xaxis.color = '#e0e0e0';
        }
        if (config.layout.yaxis) {
          config.layout.yaxis.gridcolor = '#2a2a4a';
          config.layout.yaxis.zerolinecolor = '#3a3a5a';
          config.layout.yaxis.color = '#e0e0e0';
        }
        if (config.layout.yaxis2) {
          config.layout.yaxis2.gridcolor = '#2a2a4a';
          config.layout.yaxis2.color = '#e0e0e0';
        }
        if (config.layout.legend) {
          config.layout.legend.font = {color: '#e0e0e0'};
        }
      ''';
    }

    _controller.runJavaScript('''
      try {
        var config = $configJson;
        $layoutOverride
        Plotly.react('chart', config.data, config.layout, config.config);
      } catch(e) {
        document.getElementById('chart').innerHTML = 
          '<p style="color:red;padding:20px;">Grafik hatası: ' + e.message + '</p>';
      }
    ''');
  }

  /// WebView için HTML şablonu (Plotly.js CDN dahil)
  String _buildHtml() {
    final bgColor = widget.darkMode ? '#1a1a2e' : '#ffffff';

    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { 
      background: $bgColor; 
      overflow: hidden;
      -webkit-user-select: none;
      user-select: none;
    }
    #chart { 
      width: 100vw; 
      height: 100vh; 
    }
    #loading {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 100vh;
      color: #999;
      font-family: Inter, sans-serif;
      font-size: 14px;
    }
  </style>
</head>
<body>
  <div id="chart">
    <div id="loading">Grafik yükleniyor...</div>
  </div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

/// Plotly grafiği olmadan basit bir fallback chart
/// WebView yüklenemezse veya offline modda kullanılır
class SimpleFallbackChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color color;

  const SimpleFallbackChart({
    super.key,
    required this.data,
    this.title = '',
    this.color = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: Text('Veri bulunamadı')),
      );
    }

    final values = data.map((d) => (d['value'] as num).toDouble()).toList();
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final range = maxVal - minVal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
        SizedBox(
          height: 200,
          child: CustomPaint(
            painter: _MiniChartPainter(
              values: values,
              minVal: minVal,
              range: range,
              color: color,
            ),
            size: Size.infinite,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.first['date'] ?? '', style: _labelStyle),
            Text(data.last['date'] ?? '', style: _labelStyle),
          ],
        ),
      ],
    );
  }

  TextStyle get _labelStyle => const TextStyle(
        fontSize: 10,
        color: Colors.grey,
      );
}

class _MiniChartPainter extends CustomPainter {
  final List<double> values;
  final double minVal;
  final double range;
  final Color color;

  _MiniChartPainter({
    required this.values,
    required this.minVal,
    required this.range,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2 || range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final dx = size.width / (values.length - 1);

    for (int i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - minVal) / range * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Dolgu
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.3), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}