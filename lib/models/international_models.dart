/// Uluslararası kıyaslama ve sürdürülebilirlik modelleri
///
/// Hafta 6+: Ülke kıyaslama, Dünya Bankası verileri, yeşil göstergeler

class Country {
  final int id;
  final String isoCode;
  final String iso2;
  final String nameTr;
  final String nameEn;
  final String? flagEmoji;
  final String? regionTr;

  const Country({
    required this.id,
    required this.isoCode,
    required this.iso2,
    required this.nameTr,
    required this.nameEn,
    this.flagEmoji,
    this.regionTr,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: int.parse(json['id'].toString()),
      isoCode: json['iso_code'] ?? '',
      iso2: json['iso2'] ?? '',
      nameTr: json['name_tr'] ?? '',
      nameEn: json['name_en'] ?? '',
      flagEmoji: json['flag_emoji'],
      regionTr: json['region_tr'],
    );
  }

  String get displayName => '${flagEmoji ?? ''} $nameTr'.trim();
}

class IntlIndicator {
  final int id;
  final int categoryId;
  final String sourceType;
  final String sourceCode;
  final String nameTr;
  final String nameEn;
  final String? descriptionTr;
  final String unit;
  final String frequency;
  final int decimalPlaces;
  final String? categoryNameTr;
  final String? categoryCode;

  const IntlIndicator({
    required this.id,
    required this.categoryId,
    required this.sourceType,
    required this.sourceCode,
    required this.nameTr,
    required this.nameEn,
    this.descriptionTr,
    required this.unit,
    this.frequency = 'yearly',
    this.decimalPlaces = 2,
    this.categoryNameTr,
    this.categoryCode,
  });

  factory IntlIndicator.fromJson(Map<String, dynamic> json) {
    return IntlIndicator(
      id: int.parse(json['id'].toString()),
      categoryId: int.tryParse(json['category_id']?.toString() ?? '0') ?? 0,
      sourceType: json['source_type'] ?? 'worldbank',
      sourceCode: json['source_code'] ?? '',
      nameTr: json['name_tr'] ?? '',
      nameEn: json['name_en'] ?? '',
      descriptionTr: json['description_tr'],
      unit: json['unit'] ?? '',
      frequency: json['frequency'] ?? 'yearly',
      decimalPlaces: int.tryParse(json['decimal_places']?.toString() ?? '2') ?? 2,
      categoryNameTr: json['category_name_tr'],
      categoryCode: json['category_code'],
    );
  }
}

class IntlDataPoint {
  final String date;
  final double value;

  const IntlDataPoint({required this.date, required this.value});

  factory IntlDataPoint.fromJson(Map<String, dynamic> json) {
    return IntlDataPoint(
      date: json['date'] ?? '',
      value: double.parse(json['value'].toString()),
    );
  }

  Map<String, dynamic> toJson() => {'date': date, 'value': value};
}

class CountrySeries {
  final Country? country;
  final String isoCode;
  final String nameTr;
  final String? flagEmoji;
  final List<IntlDataPoint> data;

  CountrySeries({
    this.country,
    required this.isoCode,
    required this.nameTr,
    this.flagEmoji,
    required this.data,
  });

  factory CountrySeries.fromJson(Map<String, dynamic> json) {
    final countryData = json['country'] as Map<String, dynamic>? ?? {};
    final dataList = (json['data'] as List?)
            ?.map((d) => IntlDataPoint.fromJson(d))
            .toList() ??
        [];
    return CountrySeries(
      isoCode: countryData['iso_code'] ?? '',
      nameTr: countryData['name_tr'] ?? '',
      flagEmoji: countryData['flag_emoji'],
      data: dataList,
    );
  }
}

class IntlComparisonResult {
  final IntlIndicator? indicator;
  final int startYear;
  final int endYear;
  final List<CountrySeries> series;

  IntlComparisonResult({
    this.indicator,
    required this.startYear,
    required this.endYear,
    required this.series,
  });

  factory IntlComparisonResult.fromJson(Map<String, dynamic> json) {
    final indData = json['indicator'] as Map<String, dynamic>?;
    final period = json['period'] as Map<String, dynamic>? ?? {};
    final seriesList = (json['series'] as List?)
            ?.map((s) => CountrySeries.fromJson(s))
            .toList() ??
        [];

    return IntlComparisonResult(
      indicator: indData != null ? IntlIndicator.fromJson(indData) : null,
      startYear: int.tryParse(period['start']?.toString() ?? '2000') ?? 2000,
      endYear: int.tryParse(period['end']?.toString() ?? '2024') ?? 2024,
      series: seriesList,
    );
  }
}

/// Uluslararası son değerler (dashboard özet)
class IntlLatestEntry {
  final int indicatorId;
  final String indicatorName;
  final String unit;
  final String? categoryCode;
  final String? categoryName;
  final List<CountryValue> countries;

  IntlLatestEntry({
    required this.indicatorId,
    required this.indicatorName,
    required this.unit,
    this.categoryCode,
    this.categoryName,
    required this.countries,
  });

  factory IntlLatestEntry.fromJson(Map<String, dynamic> json) {
    final ind = json['indicator'] as Map<String, dynamic>? ?? {};
    final countryList = (json['countries'] as List?)
            ?.map((c) => CountryValue.fromJson(c))
            .toList() ??
        [];
    return IntlLatestEntry(
      indicatorId: int.tryParse(ind['id']?.toString() ?? '0') ?? 0,
      indicatorName: ind['name_tr'] ?? '',
      unit: ind['unit'] ?? '',
      categoryCode: ind['category_code'],
      categoryName: ind['category'],
      countries: countryList,
    );
  }
}

class CountryValue {
  final String isoCode;
  final String nameTr;
  final String? flagEmoji;
  final double? value;
  final String? date;

  CountryValue({
    required this.isoCode,
    required this.nameTr,
    this.flagEmoji,
    this.value,
    this.date,
  });

  factory CountryValue.fromJson(Map<String, dynamic> json) {
    return CountryValue(
      isoCode: json['iso_code'] ?? '',
      nameTr: json['name_tr'] ?? '',
      flagEmoji: json['flag_emoji'],
      value: double.tryParse(json['value']?.toString() ?? ''),
      date: json['date'],
    );
  }
}