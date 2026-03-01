import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'chart_screen.dart';
import '../models/models.dart';

/// Gösterge Arama Ekranı
///
/// Anlık arama (debounce ile) yapar.
/// Sonuçlara tıklandığında grafik ekranına yönlendirir.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api = ApiService();
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Indicator> _results = [];
  bool _isSearching = false;

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isSearching = true);

    try {
      final results = await _api.searchIndicators(query);
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (_) {
      setState(() => _isSearching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Gösterge ara... (ör: enflasyon, dolar)',
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _results = []);
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _results.isEmpty
              ? Center(
                  child: Text(
                    _controller.text.length < 2
                        ? 'En az 2 karakter yazın'
                        : 'Sonuç bulunamadı',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                )
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ind = _results[index];
                    return ListTile(
                      title: Text(ind.nameTr, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${ind.categoryNameTr ?? ''} • ${ind.unit} • ${ind.evdsCode}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      trailing: ind.lastValue != null
                          ? Text(
                              ind.formattedLastValue,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            )
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChartScreen(
                            indicatorId: ind.id,
                            indicatorName: ind.nameTr,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}