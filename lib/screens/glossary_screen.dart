import 'package:flutter/material.dart';
import '../data/glossary_data.dart';

/// Hafta 3: Ekonomi Sözlüğü Ekranı
///
/// Kategorize edilmiş, aranabilir ekonomi terimleri.
/// Her terim açıklanabilir kart şeklinde gösterilir.
class GlossaryScreen extends StatefulWidget {
  const GlossaryScreen({super.key});

  @override
  State<GlossaryScreen> createState() => _GlossaryScreenState();
}

class _GlossaryScreenState extends State<GlossaryScreen> {
  final _searchController = TextEditingController();
  String _selectedCategory = 'Tümü';
  String _searchQuery = '';
  final Set<int> _expandedIndices = {};

  List<GlossaryTerm> get _filteredTerms {
    List<GlossaryTerm> results;

    if (_searchQuery.length >= 2) {
      results = GlossaryData.search(_searchQuery);
    } else {
      results = GlossaryData.getByCategory(_selectedCategory);
    }

    return results;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final terms = _filteredTerms;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ekonomi Sözlüğü'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Terim ara... (ör: enflasyon, faiz)',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _expandedIndices.clear();
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _expandedIndices.clear();
              }),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Kategori chip'leri
          if (_searchQuery.length < 2)
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                itemCount: GlossaryData.categories.length,
                itemBuilder: (context, index) {
                  final cat = GlossaryData.categories[index];
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.black : null,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: const Color(0xFF4ECDC4),
                      backgroundColor: const Color(0xFF1A1A2E),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF4ECDC4)
                            : const Color(0xFF2A2A4A),
                      ),
                      onSelected: (_) => setState(() {
                        _selectedCategory = cat;
                        _expandedIndices.clear();
                      }),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  );
                },
              ),
            ),

          // Sonuç sayısı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Icon(Icons.menu_book, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 6),
                Text(
                  '${terms.length} terim',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const Spacer(),
                if (_expandedIndices.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _expandedIndices.clear()),
                    child: Text(
                      'Tümünü kapat',
                      style: TextStyle(
                        fontSize: 11,
                        color: const Color(0xFF4ECDC4).withOpacity(0.7),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Terim listesi
          Expanded(
            child: terms.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 48, color: Colors.grey[600]),
                        const SizedBox(height: 12),
                        Text(
                          'Terim bulunamadı',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    itemCount: terms.length,
                    itemBuilder: (context, index) {
                      final term = terms[index];
                      final isExpanded = _expandedIndices.contains(index);
                      return _buildTermCard(term, index, isExpanded);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermCard(GlossaryTerm term, int index, bool isExpanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        elevation: 0,
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isExpanded
                ? const Color(0xFF4ECDC4).withOpacity(0.3)
                : const Color(0xFF2A2A4A),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => setState(() {
            if (isExpanded) {
              _expandedIndices.remove(index);
            } else {
              _expandedIndices.add(index);
            }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Başlık satırı
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _categoryColor(term.category).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        term.category,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _categoryColor(term.category),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: Colors.grey[500],
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Terim adı
                Text(
                  term.term,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 6),

                // Kısa açıklama (her zaman göster)
                Text(
                  isExpanded
                      ? term.definition
                      : _truncate(term.definition, 100),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[300],
                    height: 1.5,
                  ),
                ),

                // Genişletilmiş içerik
                if (isExpanded) ...[
                  // Formül
                  if (term.formula != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF2A2A4A),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.functions, size: 16,
                              color: const Color(0xFF45B7D1)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              term.formula!,
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                                color: Color(0xFF45B7D1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Örnek
                  if (term.example != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFA726).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 ', style: TextStyle(fontSize: 13)),
                          Expanded(
                            child: Text(
                              term.example!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[300],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // İlişkili terimler
                  if (term.relatedTerms.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        Text(
                          'İlişkili: ',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                        ...term.relatedTerms.map((t) => GestureDetector(
                              onTap: () => _searchFor(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      const Color(0xFF4ECDC4).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4ECDC4),
                                  ),
                                ),
                              ),
                            )),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _searchFor(String term) {
    _searchController.text = term;
    setState(() {
      _searchQuery = term;
      _expandedIndices.clear();
    });
  }

  String _truncate(String text, int max) {
    if (text.length <= max) return text;
    return '${text.substring(0, max)}...';
  }

  Color _categoryColor(String category) {
    return switch (category) {
      'Enflasyon & Fiyat' => const Color(0xFFFF6B6B),
      'Para Politikası' => const Color(0xFF4ECDC4),
      'Döviz & Altın' => const Color(0xFF45B7D1),
      'Büyüme & Üretim' => const Color(0xFF96CEB4),
      'İstihdam' => const Color(0xFFFFEAA7),
      'Dış Ticaret' => const Color(0xFFDDA0DD),
      'Finansal' => const Color(0xFF98D8C8),
      'Güven Endeksleri' => const Color(0xFFF7DC6F),
      'Teknik Analiz' => const Color(0xFF85C1E9),
      _ => const Color(0xFFF1948A),
    };
  }
}