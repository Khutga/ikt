// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

// Web'de HTML IFrame oluşturarak Plotly'i çalıştıran fonksiyon
Widget buildPlotlyWebView(Map<String, dynamic> config, double height, bool darkMode) {
  // Her grafik için benzersiz bir ID oluştur
  final String viewId = 'plotly-web-${DateTime.now().millisecondsSinceEpoch}-${config.hashCode}';
  final String configJson = jsonEncode(config);
  final String bgColor = darkMode ? '#1a1a2e' : '#ffffff';

  String layoutOverride = '';
  if (darkMode) {
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

  // Saf HTML ve JS içeriği
  final htmlContent = '''
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <script src="https://cdn.plot.ly/plotly-2.27.0.min.js"></script>
    <style>
      body { margin: 0; padding: 0; background: $bgColor; overflow: hidden; }
      #chart { width: 100vw; height: 100vh; }
    </style>
  </head>
  <body>
    <div id="chart"></div>
    <script>
      try {
        var config = $configJson;
        $layoutOverride
        Plotly.newPlot('chart', config.data, config.layout, config.config);
      } catch(e) {
        document.getElementById('chart').innerHTML = '<p style="color:red;">Grafik Hatası: ' + e.message + '</p>';
      }
    </script>
  </body>
  </html>
  ''';

  // Flutter Web için HTML IFrame elementini kaydet
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final iframe = html.IFrameElement()
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..srcdoc = htmlContent;
    return iframe;
  });

  return SizedBox(
    height: height,
    child: HtmlElementView(viewType: viewId),
  );
}