/// Kategori modeli
/// API'den gelen kategori verisini temsil eder.
class Category {
  final int id;
  final String code;
  final String nameTr;
  final String nameEn;
  final String? icon;
  final String? color;
  final int sortOrder;
  final int indicatorCount;

  Category({
    required this.id,
    required this.code,
    required this.nameTr,
    required this.nameEn,
    this.icon,
    this.color,
    this.sortOrder = 0,
    this.indicatorCount = 0,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: int.parse(json['id'].toString()),
      code: json['code'] ?? '',
      nameTr: json['name_tr'] ?? '',
      nameEn: json['name_en'] ?? '',
      icon: json['icon'],
      color: json['color'],
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '0') ?? 0,
      indicatorCount: int.tryParse(json['indicator_count']?.toString() ?? '0') ?? 0,
    );
  }
}

/// Gösterge modeli
/// Bir ekonomik veri serisini temsil eder (ör: TÜFE, USD/TRY).
class Indicator {
  final int id;
  final int categoryId;
  final String evdsCode;
  final String nameTr;
  final String nameEn;
  final String? descriptionTr;
  final String unit;
  final String frequency;
  final String source;
  final int decimalPlaces;
  final double? lastValue;
  final String? lastValueDate;
  final String? categoryNameTr;
  final String? categoryCode;

  Indicator({
    required this.id,
    required this.categoryId,
    required this.evdsCode,
    required this.nameTr,
    required this.nameEn,
    this.descriptionTr,
    required this.unit,
    required this.frequency,
    this.source = 'TCMB',
    this.decimalPlaces = 2,
    this.lastValue,
    this.lastValueDate,
    this.categoryNameTr,
    this.categoryCode,
  });

  factory Indicator.fromJson(Map<String, dynamic> json) {
    return Indicator(
      id: int.parse(json['id'].toString()),
      categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      evdsCode: json['evds_code'] ?? '',
      nameTr: json['name_tr'] ?? json['name'] ?? '',
      nameEn: json['name_en'] ?? '',
      descriptionTr: json['description_tr'],
      unit: json['unit'] ?? '',
      frequency: json['frequency'] ?? 'monthly',
      source: json['source'] ?? 'TCMB',
      decimalPlaces: int.tryParse(json['decimal_places']?.toString() ?? '2') ?? 2,
      lastValue: double.tryParse(json['last_value']?.toString() ?? ''),
      lastValueDate: json['last_value_date'],
      categoryNameTr: json['category_name_tr'],
      categoryCode: json['category_code'],
    );
  }

  /// Son değeri formatlı string olarak döner
  String get formattedLastValue {
    if (lastValue == null) return 'Veri yok';
    return lastValue!.toStringAsFixed(decimalPlaces);
  }
}

/// Zaman serisi veri noktası
class DataPoint {
  final DateTime date;
  final double value;

  DataPoint({required this.date, required this.value});

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      date: DateTime.parse(json['date']),
      value: double.parse(json['value'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().split('T')[0],
    'value': value,
  };
}

/// Zaman serisi - Bir göstergenin veri seti
class TimeSeries {
  final Indicator indicator;
  final List<DataPoint> data;
  final String periodStart;
  final String periodEnd;

  TimeSeries({
    required this.indicator,
    required this.data,
    required this.periodStart,
    required this.periodEnd,
  });

  factory TimeSeries.fromJson(Map<String, dynamic> json) {
    final indicator = Indicator.fromJson(json['indicator']);
    final dataList = (json['data'] as List)
        .map((d) => DataPoint.fromJson(d))
        .toList();

    return TimeSeries(
      indicator: indicator,
      data: dataList,
      periodStart: json['period']?['start'] ?? '',
      periodEnd: json['period']?['end'] ?? '',
    );
  }

  /// Seriyi Python analiz servisi formatına çevirir
  Map<String, dynamic> toAnalysisFormat() => {
    'indicator_id': indicator.id,
    'name': indicator.nameTr,
    'code': indicator.evdsCode,
    'unit': indicator.unit,
    'data': data.map((d) => d.toJson()).toList(),
  };
}

/// Dashboard özet kartı
class DashboardCategory {
  final String category;
  final String? color;
  final String? icon;
  final List<DashboardIndicator> indicators;

  DashboardCategory({
    required this.category,
    this.color,
    this.icon,
    required this.indicators,
  });

  factory DashboardCategory.fromJson(Map<String, dynamic> json) {
    final indicatorList = (json['indicators'] as List)
        .map((i) => DashboardIndicator.fromJson(i))
        .toList();

    return DashboardCategory(
      category: json['category'] ?? '',
      color: json['color'],
      icon: json['icon'],
      indicators: indicatorList,
    );
  }
}

class DashboardIndicator {
  final int id;
  final String name;
  final double? value;
  final String? date;
  final String unit;

  DashboardIndicator({
    required this.id,
    required this.name,
    this.value,
    this.date,
    required this.unit,
  });

  factory DashboardIndicator.fromJson(Map<String, dynamic> json) {
    return DashboardIndicator(
      id: int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      value: double.tryParse(json['value']?.toString() ?? ''),
      date: json['date'],
      unit: json['unit'] ?? '',
    );
  }
}

/// Analiz sonucu modeli
class AnalysisResult {
  final String analysisType;
  final Map<String, dynamic> result;
  final bool fromCache;

  AnalysisResult({
    required this.analysisType,
    required this.result,
    this.fromCache = false,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      analysisType: json['analysis_type'] ?? '',
      result: json['result'] ?? {},
      fromCache: json['from_cache'] ?? false,
    );
  }
}