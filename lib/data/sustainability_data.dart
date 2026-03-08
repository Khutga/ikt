/// Sürdürülebilirlik Sözlüğü
///
/// Yeşil ekonomi ve çevre göstergelerinin Türkçe açıklamaları.
/// GlossaryData'ya ek olarak sürdürülebilirlik terimleri.

import 'glossary_data.dart';

class SustainabilityGlossary {
  static const List<GlossaryTerm> terms = [
    GlossaryTerm(
      term: 'Karbon Emisyonu (CO₂)',
      definition:
          'Fosil yakıtların (kömür, petrol, doğalgaz) yakılması sonucu '
          'atmosfere salınan karbondioksit miktarı. İklim değişikliğinin '
          'ana sebebidir. Kişi başı veya toplam ton olarak ölçülür.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Karbon Ayak İzi', 'Paris Anlaşması', 'Net Sıfır'],
      example: 'Türkiye kişi başı ~5 ton CO₂ üretir; dünya ortalaması ~4.5 ton.',
    ),
    GlossaryTerm(
      term: 'Yenilenebilir Enerji',
      definition:
          'Güneş, rüzgar, hidroelektrik, jeotermal ve biyokütle gibi '
          'tükenmeyen kaynaklardan elde edilen enerji. Türkiye hidroelektrik '
          've jeotermal potansiyeli yüksek bir ülkedir.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Enerji Dönüşümü', 'Karbon Emisyonu'],
      example: 'Türkiye enerji üretiminin yaklaşık %40\'ını yenilenebilir kaynaklardan sağlıyor.',
    ),
    GlossaryTerm(
      term: 'Paris Anlaşması',
      definition:
          '2015\'te imzalanan uluslararası iklim anlaşması. Hedef: küresel '
          'sıcaklık artışını 1.5°C ile sınırlandırmak. Türkiye 2021\'de '
          'onayladı. Ülkelerin NDC (ulusal katkı beyanı) sunması gerekir.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Net Sıfır', 'Karbon Emisyonu'],
    ),
    GlossaryTerm(
      term: 'Net Sıfır (Net Zero)',
      definition:
          'Atmosfere salınan sera gazı miktarının, absorbe edilen miktara '
          'eşitlenmesi hedefi. Türkiye 2053 net sıfır hedefi açıkladı. '
          'AB ve ABD 2050, Çin 2060 hedefliyor.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Paris Anlaşması', 'Karbon Vergisi', 'ESG'],
    ),
    GlossaryTerm(
      term: 'ESG (Çevresel, Sosyal, Yönetişim)',
      definition:
          'Şirketlerin çevresel etki (E), sosyal sorumluluk (S) ve '
          'kurumsal yönetişim (G) performansını değerlendiren çerçeve. '
          'Yatırımcılar ESG skorlarına göre şirket seçiyor.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Yeşil Tahvil', 'Sürdürülebilir Finans'],
    ),
    GlossaryTerm(
      term: 'Yeşil Tahvil (Green Bond)',
      definition:
          'Çevresel projelerin (yenilenebilir enerji, enerji verimliliği, '
          'temiz ulaşım vb.) finansmanı için ihraç edilen borçlanma aracı. '
          'Türkiye\'de yeşil tahvil piyasası gelişmektedir.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['ESG', 'Sürdürülebilir Finans'],
    ),
    GlossaryTerm(
      term: 'Karbon Vergisi',
      definition:
          'CO₂ emisyonuna uygulanan vergi. Ton başına fiyatlandırma ile '
          'kirleticilerin maliyetini artırarak emisyon azaltmayı teşvik eder. '
          'AB\'nin Sınırda Karbon Düzenleme Mekanizması (CBAM) Türkiye\'yi '
          'doğrudan etkiler.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Karbon Emisyonu', 'CBAM'],
    ),
    GlossaryTerm(
      term: 'CBAM (Sınırda Karbon Düzenleme Mekanizması)',
      definition:
          'AB\'nin 2026\'da tam uygulamaya geçecek mekanizması. Karbon fiyatı '
          'düşük ülkelerden ithal edilen ürünlere ek vergi uygulanır. '
          'Türkiye\'nin AB\'ye ihracatını doğrudan etkiler (çelik, alüminyum, çimento).',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Karbon Vergisi', 'İhracat'],
    ),
    GlossaryTerm(
      term: 'Enerji Yoğunluğu',
      definition:
          'Bir birim GSYİH üretmek için harcanan enerji miktarı. '
          'Düşük enerji yoğunluğu = daha verimli ekonomi. '
          'Türkiye\'nin enerji yoğunluğu AB ortalamasının üzerindedir.',
      category: 'Yeşil & Sürdürülebilirlik',
      formula: 'Enerji Yoğunluğu = Toplam Enerji Tüketimi / GSYİH',
      relatedTerms: ['Enerji Verimliliği', 'GSYİH'],
    ),
    GlossaryTerm(
      term: 'Karbon Ayak İzi',
      definition:
          'Bir birey, kuruluş veya ürünün neden olduğu toplam sera gazı '
          'emisyonu. Üretimden tüketime, ulaşımdan ısınmaya tüm aktiviteleri kapsar.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Karbon Emisyonu', 'Net Sıfır'],
    ),
    GlossaryTerm(
      term: 'Döngüsel Ekonomi',
      definition:
          'Atıkları minimize edip kaynakları tekrar tekrar kullanmayı hedefleyen '
          'ekonomik model. "Al-yap-at" yerine "al-yap-geri dönüştür" mantığı. '
          'AB Yeşil Mutabakat\'ın temel bileşenidir.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Sürdürülebilir Kalkınma', 'ESG'],
    ),
    GlossaryTerm(
      term: 'Sürdürülebilir Kalkınma Amaçları (SKA)',
      definition:
          'BM\'nin 2030 hedefleri: 17 küresel amaç. Yoksulluğun sona erdirilmesi, '
          'temiz enerji, iklim eylemi, sürdürülebilir şehirler vb. '
          'Türkiye SKA Gönüllü Ulusal İncelemesi sunmuştur.',
      category: 'Yeşil & Sürdürülebilirlik',
      relatedTerms: ['Net Sıfır', 'Paris Anlaşması'],
    ),
  ];
}