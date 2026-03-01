import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Favori gösterge yönetimi
///
/// SharedPreferences ile cihaz bazlı favori saklar.
/// Dashboard'da favoriler en üstte gösterilir.
class FavoritesService {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _key = 'favorite_indicator_ids';
  SharedPreferences? _prefs;

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  /// Favori ID listesini döner
  Future<List<int>> getFavorites() async {
    final prefs = await _preferences;
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) => e as int).toList();
  }

  /// Favori mi kontrol et
  Future<bool> isFavorite(int indicatorId) async {
    final favorites = await getFavorites();
    return favorites.contains(indicatorId);
  }

  /// Favori ekle/çıkar (toggle)
  Future<bool> toggleFavorite(int indicatorId) async {
    final prefs = await _preferences;
    final favorites = await getFavorites();

    bool isNowFavorite;
    if (favorites.contains(indicatorId)) {
      favorites.remove(indicatorId);
      isNowFavorite = false;
    } else {
      favorites.add(indicatorId);
      isNowFavorite = true;
    }

    await prefs.setString(_key, jsonEncode(favorites));
    return isNowFavorite;
  }

  /// Favori sırasını değiştir
  Future<void> reorderFavorites(List<int> newOrder) async {
    final prefs = await _preferences;
    await prefs.setString(_key, jsonEncode(newOrder));
  }
}