/// Ekonometrik Analiz Grafik Oluşturucu
///
/// Python servisinden dönen ekonometrik sonuçları
/// Plotly.js grafik konfigürasyonlarına çevirir.
///
/// Desteklenen grafikler:
/// - IRF (Etki-Tepki Fonksiyonları)
/// - FEVD (Varyans Ayrıştırma)
/// - GARCH Koşullu Volatilite
/// - OLS Residual (Artık) Grafikleri
/// - Saçılım + Regresyon Çizgisi
/// - Birim Kök Görselleştirme
/// - Korelasyon Isı Haritası

class EconometricsChartBuilder {
  static final EconometricsChartBuilder _instance =
      EconometricsChartBuilder._internal();
  factory EconometricsChartBuilder() => _instance;
  EconometricsChartBuilder._internal();

  // Renk paleti
  static const List<String> colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
    '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F',
    '#85C1E9', '#F1948A', '#BB86FC', '#03DAC6',
  ];

  // ═══════════════════════════════════════════
  //  IRF (ETKİ-TEPKİ FONKSİYONLARI)
  // ═══════════════════════════════════════════

  /// VAR modelinden dönen IRF verisini Plotly grafiğine çevirir.
  /// Her şok-tepki çifti için ayrı bir subplot veya tek grafik.
  List<Map<String, dynamic>> buildIrfCharts(Map<String, dynamic> irfData) {
    final charts = <Map<String, dynamic>>[];

    if (irfData.containsKey('error')) return charts;

    final periods = irfData['periods'] as int? ?? 12;
    final responses = irfData['responses'] as Map<String, dynamic>? ?? {};

    // Her şok-tepki çifti için bir grafik
    responses.forEach((key, data) {
      final parts = key.split('_to_');
      if (parts.length != 2) return;

      final shockVar = parts[0];
      final responseVar = parts[1];
      final values = (data['values'] as List?)?.map((v) => v as num).toList() ?? [];
      final lower = (data['lower'] as List?)?.map((v) => v as num).toList();
      final upper = (data['upper'] as List?)?.map((v) => v as num).toList();

      if (values.isEmpty) return;

      final xVals = List.generate(values.length, (i) => i);

      final traces = <Map<String, dynamic>>[
        // Ana IRF çizgisi
        {
          'type': 'scatter',
          'mode': 'lines+markers',
          'name': 'IRF',
          'x': xVals,
          'y': values.map((v) => v.toDouble()).toList(),
          'line': {'color': '#4ECDC4', 'width': 2.5},
          'marker': {'size': 4},
          'hovertemplate': 'Dönem: %{x}<br>Tepki: %{y:.4f}<extra></extra>',
        },
        // Sıfır çizgisi
        {
          'type': 'scatter',
          'mode': 'lines',
          'name': 'Sıfır',
          'x': xVals,
          'y': List.filled(values.length, 0),
          'line': {'color': '#666', 'width': 1, 'dash': 'dash'},
          'showlegend': false,
        },
      ];

      // Güven aralığı bantları
      if (upper != null && lower != null) {
        traces.add({
          'type': 'scatter',
          'mode': 'lines',
          'name': 'Üst Sınır (%95)',
          'x': xVals,
          'y': upper.map((v) => v.toDouble()).toList(),
          'line': {'color': '#4ECDC4', 'width': 0},
          'showlegend': false,
        });
        traces.add({
          'type': 'scatter',
          'mode': 'lines',
          'name': 'Alt Sınır (%95)',
          'x': xVals,
          'y': lower.map((v) => v.toDouble()).toList(),
          'line': {'color': '#4ECDC4', 'width': 0},
          'fill': 'tonexty',
          'fillcolor': 'rgba(78,205,196,0.15)',
          'showlegend': false,
        });
      }

      charts.add({
        'title': '$shockVar → $responseVar',
        'config': {
          'data': traces,
          'layout': _baseLayout('Etki-Tepki: $shockVar → $responseVar', xTitle: 'Dönem', yTitle: 'Tepki'),
          'config': _baseConfig(),
        },
      });
    });

    return charts;
  }

  // ═══════════════════════════════════════════
  //  FEVD (VARYANS AYRIŞTIRMA)
  // ═══════════════════════════════════════════

  /// Varyans ayrıştırma sonuçlarını stacked area chart'a çevirir.
  List<Map<String, dynamic>> buildFevdCharts(Map<String, dynamic> fevdData) {
    final charts = <Map<String, dynamic>>[];

    if (fevdData.containsKey('error')) return charts;

    fevdData.forEach((varName, data) {
      if (data is! Map<String, dynamic>) return;

      final periods = (data['periods'] as List?)?.map((p) => p as int).toList() ?? [];
      final decomposition = data['decomposition'] as Map<String, dynamic>? ?? {};

      if (periods.isEmpty || decomposition.isEmpty) return;

      final traces = <Map<String, dynamic>>[];
      int colorIdx = 0;

      decomposition.forEach((contributorName, values) {
        final yVals = (values as List).map((v) => (v as num).toDouble()).toList();
        final color = colors[colorIdx % colors.length];

        traces.add({
          'type': 'scatter',
          'mode': 'lines',
          'name': contributorName,
          'x': periods,
          'y': yVals,
          'fill': colorIdx == 0 ? 'tozeroy' : 'tonexty',
          'line': {'color': color, 'width': 0.5},
          'fillcolor': '${color}B3', // %70 opacity
          'hovertemplate': '$contributorName<br>Dönem: %{x}<br>Pay: %{y:.1f}%<extra></extra>',
          'stackgroup': 'one',
        });
        colorIdx++;
      });

      final layout = _baseLayout(
        'Varyans Ayrıştırma: $varName',
        xTitle: 'Dönem',
        yTitle: 'Pay (%)',
      );
      layout['yaxis'] = {
        ...(layout['yaxis'] as Map<String, dynamic>),
        'range': [0, 100],
      };

      charts.add({
        'title': 'FEVD: $varName',
        'config': {
          'data': traces,
          'layout': layout,
          'config': _baseConfig(),
        },
      });
    });

    return charts;
  }

  // ═══════════════════════════════════════════
  //  GARCH KOŞULLU VOLATİLİTE
  // ═══════════════════════════════════════════

  /// GARCH modelinden dönen koşullu volatilite serisini çizer.
  Map<String, dynamic>? buildVolatilityChart(Map<String, dynamic> garchResult) {
    final condVol = garchResult['conditional_volatility'] as Map<String, dynamic>?;
    if (condVol == null) return null;

    final recent = condVol['recent'] as List? ?? [];
    if (recent.isEmpty) return null;

    final dates = recent.map((d) => d['date'].toString()).toList();
    final values = recent.map((d) => (d['volatility'] as num).toDouble()).toList();
    final meanVol = (condVol['mean_vol'] as num?)?.toDouble();

    final traces = <Map<String, dynamic>>[
      // Volatilite çizgisi
      {
        'type': 'scatter',
        'mode': 'lines',
        'name': 'Koşullu Volatilite',
        'x': dates,
        'y': values,
        'line': {'color': '#FF6B6B', 'width': 2},
        'fill': 'tozeroy',
        'fillcolor': 'rgba(255,107,107,0.1)',
        'hovertemplate': 'Tarih: %{x}<br>Volatilite: %{y:.4f}<extra></extra>',
      },
    ];

    // Ortalama volatilite çizgisi
    if (meanVol != null) {
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'Ortalama',
        'x': dates,
        'y': List.filled(dates.length, meanVol),
        'line': {'color': '#FFA726', 'width': 1.5, 'dash': 'dash'},
        'hovertemplate': 'Ortalama: %{y:.4f}<extra></extra>',
      });
    }

    return {
      'data': traces,
      'layout': _baseLayout('GARCH Koşullu Volatilite', xTitle: '', yTitle: 'Volatilite (%)'),
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  OLS RESİDUAL GRAFİKLERİ
  // ═══════════════════════════════════════════

  /// OLS regresyon sonuçlarından katsayı grafiği oluşturur.
  Map<String, dynamic>? buildCoefficientsChart(Map<String, dynamic> olsResult) {
    final coefficients = olsResult['coefficients'] as Map<String, dynamic>?;
    if (coefficients == null || coefficients.isEmpty) return null;

    final names = <String>[];
    final values = <double>[];
    final pValues = <double>[];
    final barColors = <String>[];

    coefficients.forEach((name, data) {
      if (name == 'const') return; // Sabit terimi atla
      final coefData = data as Map<String, dynamic>;
      names.add(name.length > 20 ? '${name.substring(0, 18)}...' : name);
      values.add((coefData['value'] as num).toDouble());
      final pVal = (coefData['p_value'] as num).toDouble();
      pValues.add(pVal);
      barColors.add(pVal < 0.05 ? '#4ECDC4' : '#666666');
    });

    if (names.isEmpty) return null;

    final traces = <Map<String, dynamic>>[
      {
        'type': 'bar',
        'name': 'Katsayı',
        'x': names,
        'y': values,
        'marker': {'color': barColors},
        'hovertemplate': '%{x}<br>Katsayı: %{y:.4f}<extra></extra>',
      },
    ];

    final layout = _baseLayout('Regresyon Katsayıları', xTitle: '', yTitle: 'Katsayı Değeri');
    layout['annotations'] = [
      {
        'text': '■ Anlamlı (p<0.05)  ■ Anlamsız',
        'xref': 'paper',
        'yref': 'paper',
        'x': 1,
        'y': -0.15,
        'showarrow': false,
        'font': {'size': 10, 'color': '#999'},
      }
    ];

    return {
      'data': traces,
      'layout': layout,
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  KORELASYON ISI HARİTASI (PLOTLY)
  // ═══════════════════════════════════════════

  /// Korelasyon matrisini Plotly heatmap'e çevirir.
  Map<String, dynamic>? buildCorrelationHeatmap(Map<String, dynamic> corrResult) {
    final pearson = corrResult['pearson'] as Map<String, dynamic>?;
    if (pearson == null) return null;

    final matrix = pearson['matrix'] as Map<String, dynamic>?;
    if (matrix == null || matrix.isEmpty) return null;

    final vars = matrix.keys.toList();
    final zValues = <List<double>>[];

    for (final row in vars) {
      final rowData = matrix[row] as Map<String, dynamic>;
      final rowValues = <double>[];
      for (final col in vars) {
        rowValues.add((rowData[col] as num?)?.toDouble() ?? 0);
      }
      zValues.add(rowValues);
    }

    // Kısa isimler
    final shortNames = vars.map((v) {
      if (v.length > 15) return '${v.substring(0, 13)}..';
      return v;
    }).toList();

    // Hücre değerlerini metin olarak
    final textValues = zValues.map((row) => row.map((v) => v.toStringAsFixed(2)).toList()).toList();

    final traces = <Map<String, dynamic>>[
      {
        'type': 'heatmap',
        'z': zValues,
        'x': shortNames,
        'y': shortNames,
        'text': textValues,
        'texttemplate': '%{text}',
        'colorscale': [
          [0, '#FF6B6B'],
          [0.5, '#2A2A4A'],
          [1, '#4ECDC4'],
        ],
        'zmin': -1,
        'zmax': 1,
        'colorbar': {
          'title': 'r',
          'titleside': 'right',
          'tickfont': {'color': '#e0e0e0'},
          'titlefont': {'color': '#e0e0e0'},
        },
        'hovertemplate': '%{y} ↔ %{x}<br>r = %{z:.4f}<extra></extra>',
      },
    ];

    final layout = _baseLayout('Pearson Korelasyon Matrisi', xTitle: '', yTitle: '');
    layout['margin'] = {'l': 120, 'r': 60, 't': 60, 'b': 100};

    return {
      'data': traces,
      'layout': layout,
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  ROLLING KORELASYON GRAFİĞİ
  // ═══════════════════════════════════════════

  Map<String, dynamic>? buildRollingCorrelationChart(Map<String, dynamic> corrResult) {
    final rolling = corrResult['rolling_correlation'] as Map<String, dynamic>?;
    if (rolling == null) return null;

    final data = rolling['data'] as List? ?? [];
    if (data.isEmpty) return null;

    final dates = data.map((d) => d['date'].toString()).toList();
    final values = data.map((d) => (d['correlation'] as num).toDouble()).toList();
    final meanCorr = (rolling['mean'] as num?)?.toDouble();

    final traces = <Map<String, dynamic>>[
      {
        'type': 'scatter',
        'mode': 'lines',
        'name': 'Rolling Korelasyon',
        'x': dates,
        'y': values,
        'line': {'color': '#45B7D1', 'width': 2},
        'hovertemplate': 'Tarih: %{x}<br>r = %{y:.3f}<extra></extra>',
      },
      // Sıfır çizgisi
      {
        'type': 'scatter',
        'mode': 'lines',
        'name': '',
        'x': dates,
        'y': List.filled(dates.length, 0),
        'line': {'color': '#666', 'width': 1, 'dash': 'dot'},
        'showlegend': false,
      },
    ];

    if (meanCorr != null) {
      traces.add({
        'type': 'scatter',
        'mode': 'lines',
        'name': 'Ortalama',
        'x': dates,
        'y': List.filled(dates.length, meanCorr),
        'line': {'color': '#FFA726', 'width': 1, 'dash': 'dash'},
      });
    }

    final window = rolling['window'] ?? 30;

    return {
      'data': traces,
      'layout': _baseLayout('Rolling Korelasyon (Pencere: $window)', xTitle: '', yTitle: 'Korelasyon'),
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  BİRİM KÖK GÖRSELLEŞTİRME
  // ═══════════════════════════════════════════

  /// Birim kök test sonuçlarını bar chart olarak gösterir.
  /// ADF test istatistiği vs kritik değerler.
  Map<String, dynamic>? buildUnitRootChart(Map<String, dynamic> urResult) {
    // Tek seri veya çoklu seri
    final seriesResults = urResult['series_results'] as List?;
    final singleResult = seriesResults == null ? urResult : null;
    final results = seriesResults ?? [singleResult];

    final categories = <String>[];
    final adfStats = <double>[];
    final cv5 = <double>[];
    final barColors = <String>[];

    for (final sr in results) {
      if (sr == null) continue;
      final name = (sr['series_name'] ?? 'Seri').toString();
      final io = sr['integration_order'];

      // Düzey ADF
      final levels = sr['levels'] as Map<String, dynamic>?;
      final adf = levels?['adf'] as Map<String, dynamic>?;
      if (adf != null && !adf.containsKey('error')) {
        categories.add('$name\n(Düzey)');
        adfStats.add((adf['statistic'] as num).toDouble());
        final cvs = adf['critical_values'] as Map<String, dynamic>? ?? {};
        cv5.add((cvs['5%'] as num?)?.toDouble() ?? -2.86);
        barColors.add(adf['is_stationary'] == true ? '#4ECDC4' : '#FF6B6B');
      }

      // 1. Fark ADF
      final firstDiff = sr['first_diff'] as Map<String, dynamic>?;
      final adfDiff = firstDiff?['adf'] as Map<String, dynamic>?;
      if (adfDiff != null && !adfDiff.containsKey('error')) {
        categories.add('$name\n(1.Fark)');
        adfStats.add((adfDiff['statistic'] as num).toDouble());
        final cvs = adfDiff['critical_values'] as Map<String, dynamic>? ?? {};
        cv5.add((cvs['5%'] as num?)?.toDouble() ?? -2.86);
        barColors.add(adfDiff['is_stationary'] == true ? '#4ECDC4' : '#FF6B6B');
      }
    }

    if (categories.isEmpty) return null;

    final traces = <Map<String, dynamic>>[
      {
        'type': 'bar',
        'name': 'ADF İstatistiği',
        'x': categories,
        'y': adfStats,
        'marker': {'color': barColors},
        'hovertemplate': '%{x}<br>ADF: %{y:.3f}<extra></extra>',
      },
      {
        'type': 'scatter',
        'mode': 'lines+markers',
        'name': 'Kritik Değer (%5)',
        'x': categories,
        'y': cv5,
        'line': {'color': '#FFA726', 'width': 2, 'dash': 'dash'},
        'marker': {'size': 6, 'symbol': 'diamond'},
        'hovertemplate': 'Kritik Değer: %{y:.3f}<extra></extra>',
      },
    ];

    final layout = _baseLayout('ADF Birim Kök Testi', xTitle: '', yTitle: 'Test İstatistiği');
    layout['annotations'] = [
      {
        'text': '■ Durağan  ■ Durağan Değil  ◆ %5 Kritik Değer',
        'xref': 'paper',
        'yref': 'paper',
        'x': 0.5,
        'y': -0.2,
        'showarrow': false,
        'font': {'size': 10, 'color': '#999'},
      }
    ];

    return {
      'data': traces,
      'layout': layout,
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  GRANGER NEDENSELLİK GRAFİĞİ
  // ═══════════════════════════════════════════

  /// Granger nedensellik sonuçlarını yönlü ok grafiği yerine
  /// p-değeri bar chart olarak gösterir.
  Map<String, dynamic>? buildGrangerChart(Map<String, dynamic> grangerResult) {
    final tests = grangerResult['tests'] as List? ?? [];
    if (tests.isEmpty) return null;

    final directions = <String>[];
    final pValues = <double>[];
    final barColors = <String>[];

    for (final test in tests) {
      if (test is! Map<String, dynamic> || test.containsKey('error')) continue;
      final dir = test['direction']?.toString() ?? '';
      final p = (test['best_p_value'] as num?)?.toDouble() ?? 1.0;
      final isCausal = test['is_granger_cause'] == true;

      directions.add(dir.length > 25 ? '${dir.substring(0, 23)}..' : dir);
      pValues.add(p);
      barColors.add(isCausal ? '#4ECDC4' : '#666666');
    }

    if (directions.isEmpty) return null;

    final traces = <Map<String, dynamic>>[
      {
        'type': 'bar',
        'name': 'p-değeri',
        'y': directions,
        'x': pValues,
        'orientation': 'h',
        'marker': {'color': barColors},
        'hovertemplate': '%{y}<br>p = %{x:.4f}<extra></extra>',
      },
      // %5 anlamlılık çizgisi
      {
        'type': 'scatter',
        'mode': 'lines',
        'name': '%5 anlamlılık',
        'y': directions,
        'x': List.filled(directions.length, 0.05),
        'line': {'color': '#FF6B6B', 'width': 2, 'dash': 'dash'},
        'hovertemplate': 'Anlamlılık sınırı: 0.05<extra></extra>',
      },
    ];

    final layout = _baseLayout('Granger Nedensellik (p-değerleri)', xTitle: 'p-değeri', yTitle: '');
    layout['margin'] = {'l': 180, 'r': 60, 't': 60, 'b': 50};
    layout['xaxis'] = {
      ...(layout['xaxis'] as Map<String, dynamic>),
      'range': [0, 1],
    };

    return {
      'data': traces,
      'layout': layout,
      'config': _baseConfig(),
    };
  }

  // ═══════════════════════════════════════════
  //  TAM ANALİZ İÇİN TOPLU GRAFİK
  // ═══════════════════════════════════════════

  /// full_analysis sonuçlarından tüm grafikleri üretir.
  List<Map<String, dynamic>> buildFullAnalysisCharts(Map<String, dynamic> result) {
    final charts = <Map<String, dynamic>>[];
    final sections = result['sections'] as Map<String, dynamic>? ?? {};

    // Birim kök
    if (sections['unit_root'] is List) {
      final combined = <String, dynamic>{
        'series_results': sections['unit_root'],
      };
      final urChart = buildUnitRootChart(combined);
      if (urChart != null) {
        charts.add({'title': 'Birim Kök Testleri', 'config': urChart});
      }
    }

    // Korelasyon
    if (sections['correlation'] is Map<String, dynamic>) {
      final corrHeatmap = buildCorrelationHeatmap(sections['correlation']);
      if (corrHeatmap != null) {
        charts.add({'title': 'Korelasyon Matrisi', 'config': corrHeatmap});
      }
      final rollingChart = buildRollingCorrelationChart(sections['correlation']);
      if (rollingChart != null) {
        charts.add({'title': 'Rolling Korelasyon', 'config': rollingChart});
      }
    }

    // Granger
    if (sections['granger'] is Map<String, dynamic>) {
      final grangerChart = buildGrangerChart(sections['granger']);
      if (grangerChart != null) {
        charts.add({'title': 'Granger Nedensellik', 'config': grangerChart});
      }
    }

    return charts;
  }

  // ═══════════════════════════════════════════
  //  YARDIMCI
  // ═══════════════════════════════════════════

  Map<String, dynamic> _baseLayout(String title, {String xTitle = '', String yTitle = ''}) {
    return {
      'title': {
        'text': title,
        'font': {'size': 14, 'color': '#e0e0e0'},
        'x': 0.05,
      },
      'xaxis': {
        'title': xTitle,
        'showgrid': true,
        'gridcolor': '#2a2a4a',
        'color': '#e0e0e0',
        'titlefont': {'size': 11},
      },
      'yaxis': {
        'title': yTitle,
        'showgrid': true,
        'gridcolor': '#2a2a4a',
        'color': '#e0e0e0',
        'zeroline': true,
        'zerolinecolor': '#444',
        'titlefont': {'size': 11},
      },
      'legend': {
        'orientation': 'h',
        'yanchor': 'bottom',
        'y': 1.02,
        'xanchor': 'right',
        'x': 1,
        'font': {'color': '#e0e0e0'},
      },
      'margin': {'l': 65, 'r': 30, 't': 60, 'b': 50},
      'paper_bgcolor': '#1a1a2e',
      'plot_bgcolor': '#16213e',
      'font': {'family': 'Inter, sans-serif', 'color': '#e0e0e0'},
      'hovermode': 'closest',
    };
  }

  Map<String, dynamic> _baseConfig() {
    return {
      'responsive': true,
      'displayModeBar': true,
      'modeBarButtonsToRemove': ['lasso2d', 'select2d', 'autoScale2d'],
      'displaylogo': false,
      'locale': 'tr',
    };
  }
}