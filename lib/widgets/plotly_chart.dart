import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// SİHİRLİ SATIR: Derleme ortamına göre doğru dosyayı çeker
import 'plotly_chart_stub.dart' if (dart.library.html) 'plotly_chart_web.dart';

/// PlotlyChart - Plotly.js ile interaktif grafik widget'ı
class PlotlyChart extends StatefulWidget {
  final Map<String, dynamic> plotlyConfig;
  final double height;
  final bool darkMode;
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
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // MOBİL İÇİN WebView Başlat
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.darkMode ? Colors.grey[900]! : Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (_) {
              _renderChartMobile();
              setState(() => _isLoading = false);
              widget.onLoaded?.call();
            },
          ),
        )
        ..loadHtmlString(_buildHtmlMobile());
    }
  }

  @override
  void didUpdateWidget(PlotlyChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!kIsWeb && oldWidget.plotlyConfig != widget.plotlyConfig) {
      _renderChartMobile();
    }
  }

  void _renderChartMobile() {
    if (_controller == null) return;
    
    final configJson = jsonEncode(widget.plotlyConfig);
    String layoutOverride = '';
    
    if (widget.darkMode) {
      layoutOverride = '''
        config.layout.paper_bgcolor = '#1a1a2e';
        config.layout.plot_bgcolor = '#16213e';
        config.layout.font = {color: '#e0e0e0', family: 'Inter, sans-serif'};
        if (config.layout.xaxis) { config.layout.xaxis.gridcolor = '#2a2a4a'; config.layout.xaxis.color = '#e0e0e0'; }
        if (config.layout.yaxis) { config.layout.yaxis.gridcolor = '#2a2a4a'; config.layout.yaxis.color = '#e0e0e0'; }
        if (config.layout.yaxis2) { config.layout.yaxis2.gridcolor = '#2a2a4a'; config.layout.yaxis2.color = '#e0e0e0'; }
        if (config.layout.legend) { config.layout.legend.font = {color: '#e0e0e0'}; }
      ''';
    }

    _controller!.runJavaScript('''
      try {
        var config = $configJson;
        $layoutOverride
        Plotly.react('chart', config.data, config.layout, config.config);
      } catch(e) { }
    ''');
  }

  String _buildHtmlMobile() {
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
    body { background: $bgColor; overflow: hidden; -webkit-user-select: none; user-select: none; }
    #chart { width: 100vw; height: 100vh; }
  </style>
</head>
<body>
  <div id="chart"></div>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    // WEB İÇİN GÖRÜNÜM (IFrame ile Plotly)
    if (kIsWeb) {
      return buildPlotlyWebView(widget.plotlyConfig, widget.height, widget.darkMode);
    }

    // MOBİL İÇİN GÖRÜNÜM (WebView)
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Eski Fallback Sınıflarını korumak istersen aşağıda:
// ----------------------------------------------------
class SimpleFallbackChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final Color color;

  const SimpleFallbackChart({super.key, required this.data, this.title = '', this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text('Veri bulunamadı')));
    return const SizedBox(); // Gerekirse önceki içeriği ekleyebilirsin
  }
}