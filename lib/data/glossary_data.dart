/// Ekonomi Sözlüğü Veritabanı
///
/// Hafta 3: Temel ekonomik terimlerin Türkçe açıklamaları.
/// Kategorize edilmiş, aranabilir yapıda.

class GlossaryTerm {
  final String term;
  final String definition;
  final String category;
  final String? formula;
  final List<String> relatedTerms;
  final String? example;

  const GlossaryTerm({
    required this.term,
    required this.definition,
    required this.category,
    this.formula,
    this.relatedTerms = const [],
    this.example,
  });
}

class GlossaryData {
  static const List<String> categories = [
    'Tümü',
    'Enflasyon & Fiyat',
    'Para Politikası',
    'Döviz & Altın',
    'Büyüme & Üretim',
    'İstihdam',
    'Dış Ticaret',
    'Finansal',
    'Güven Endeksleri',
    'Teknik Analiz',
    'Genel',
  ];

  static const List<GlossaryTerm> terms = [
    // ── ENF LASYON & FİYAT ──
    GlossaryTerm(
      term: 'TÜFE (Tüketici Fiyat Endeksi)',
      definition:
          'Tüketicilerin satın aldığı mal ve hizmet sepetinin fiyatındaki '
          'değişimi ölçen endeks. Enflasyonun en yaygın göstergesidir. '
          'TÜİK tarafından aylık olarak açıklanır.',
      category: 'Enflasyon & Fiyat',
      formula: 'TÜFE = (Cari Dönem Sepet Maliyeti / Baz Dönem Sepet Maliyeti) × 100',
      relatedTerms: ['ÜFE', 'Enflasyon', 'Çekirdek Enflasyon'],
      example: 'TÜFE yıllık %65 ise, geçen yıl 100 TL olan sepet bu yıl 165 TL.',
    ),
    GlossaryTerm(
      term: 'ÜFE (Üretici Fiyat Endeksi)',
      definition:
          'Üreticilerin ürettikleri malların fiyatındaki değişimi ölçer. '
          'TÜFE\'nin öncü göstergesidir; üretici fiyatları genellikle '
          'tüketiciye yansımadan önce artar.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['TÜFE', 'Maliyet Enflasyonu'],
    ),
    GlossaryTerm(
      term: 'Enflasyon',
      definition:
          'Fiyatlar genel düzeyinin sürekli ve belirgin biçimde artması. '
          'Paranın satın alma gücünün düşmesi anlamına gelir. '
          'Hiperenflasyon: yıllık %50+ artış.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['TÜFE', 'Deflasyon', 'Stagflasyon', 'Dezenflasyon'],
      example: 'Enflasyon %50 ise 1 yıl önce 10 TL olan ekmek şimdi 15 TL.',
    ),
    GlossaryTerm(
      term: 'Deflasyon',
      definition:
          'Fiyatlar genel düzeyinin sürekli düşmesi. Ekonomik daralma sinyali '
          'olabilir. Tüketiciler harcamalarını erteler, bu da durgunluğu derinleştirir.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['Enflasyon', 'Stagflasyon'],
    ),
    GlossaryTerm(
      term: 'Dezenflasyon',
      definition:
          'Enflasyon oranının düşmesi (fiyatlar hâlâ artıyor ama daha yavaş). '
          'Deflasyondan farklıdır; fiyatlar düşmez, artış hızı yavaşlar.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['Enflasyon', 'Deflasyon'],
      example: 'Enflasyon %75\'ten %45\'e düştüyse bu dezenflasyondur.',
    ),
    GlossaryTerm(
      term: 'Stagflasyon',
      definition:
          'Ekonomik durgunluk (düşük büyüme) ile yüksek enflasyonun aynı '
          'anda yaşanması. Merkez bankası için ikilem yaratır: faiz artırsa '
          'büyüme daha da düşer, indirse enflasyon artar.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['Enflasyon', 'Resesyon', 'GSYİH'],
    ),
    GlossaryTerm(
      term: 'Çekirdek Enflasyon',
      definition:
          'Gıda ve enerji gibi değişken kalemlerin çıkarıldığı enflasyon ölçümü. '
          'Enflasyonun kalıcı eğilimini gösterir. TCMB\'nin politika kararlarında '
          'önemli bir referanstır.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['TÜFE', 'Enflasyon Beklentisi'],
    ),
    GlossaryTerm(
      term: 'Enflasyon Beklentisi',
      definition:
          'Ekonomik aktörlerin gelecek 12 ay için öngördüğü enflasyon oranı. '
          'TCMB anket sonuçlarıyla ölçülür. Beklentiler kendini gerçekleştiren '
          'kehanet olabilir.',
      category: 'Enflasyon & Fiyat',
      relatedTerms: ['Enflasyon', 'TCMB', 'Politika Faizi'],
    ),

    // ── PARA POLİTİKASI ──
    GlossaryTerm(
      term: 'Politika Faizi',
      definition:
          'TCMB\'nin para politikası duruşunu yansıtan ana faiz oranı. '
          'Haftalık repo ihale faiz oranı olarak belirlenir. '
          'Tüm faiz oranlarını doğrudan etkiler.',
      category: 'Para Politikası',
      relatedTerms: ['TCMB', 'Repo', 'Faiz Koridoru'],
      example: 'Politika faizi %50 ise bankalar TCMB\'den %50 ile borçlanır.',
    ),
    GlossaryTerm(
      term: 'TCMB (Türkiye Cumhuriyet Merkez Bankası)',
      definition:
          'Türkiye\'nin merkez bankası. Temel görevi fiyat istikrarını sağlamaktır. '
          'Para politikası araçları: politika faizi, zorunlu karşılıklar, '
          'açık piyasa işlemleri, döviz müdahaleleri.',
      category: 'Para Politikası',
      relatedTerms: ['Politika Faizi', 'Enflasyon Hedeflemesi'],
    ),
    GlossaryTerm(
      term: 'Repo',
      definition:
          'Geri alım anlaşması. Menkul kıymeti belirli bir tarihte geri almak '
          'üzere satma işlemi. TCMB bankacılık sistemine repo yoluyla likidite sağlar.',
      category: 'Para Politikası',
      relatedTerms: ['Politika Faizi', 'Ters Repo', 'Likidite'],
    ),
    GlossaryTerm(
      term: 'Zorunlu Karşılık',
      definition:
          'Bankaların mevduatlarının belirli bir oranını TCMB\'de tutma zorunluluğu. '
          'Artırılırsa bankalar daha az kredi verebilir → para arzı daralır.',
      category: 'Para Politikası',
      relatedTerms: ['TCMB', 'Para Arzı', 'Kredi'],
    ),
    GlossaryTerm(
      term: 'Sıkılaştırma (Hawkish)',
      definition:
          'Merkez bankasının faiz artırarak veya likiditeyi azaltarak '
          'enflasyonla mücadele etmesi. Genellikle TL\'yi güçlendirir '
          'ama büyümeyi yavaşlatır.',
      category: 'Para Politikası',
      relatedTerms: ['Gevşeme', 'Politika Faizi', 'Enflasyon'],
    ),
    GlossaryTerm(
      term: 'Gevşeme (Dovish)',
      definition:
          'Merkez bankasının faiz indirerek veya likiditeyi artırarak '
          'ekonomiyi canlandırmaya çalışması. Büyümeyi destekler ama '
          'enflasyon riski taşır.',
      category: 'Para Politikası',
      relatedTerms: ['Sıkılaştırma', 'Politika Faizi'],
    ),

    // ── DÖVİZ & ALTIN ──
    GlossaryTerm(
      term: 'Döviz Kuru',
      definition:
          'Bir ülke para biriminin başka bir para birimi cinsinden değeri. '
          'USD/TRY = 30 ise 1 Dolar = 30 TL demektir.',
      category: 'Döviz & Altın',
      relatedTerms: ['Devalüasyon', 'Revalüasyon', 'Cari Açık'],
    ),
    GlossaryTerm(
      term: 'Devalüasyon',
      definition:
          'Ulusal paranın yabancı paralar karşısında değer kaybetmesi. '
          'İhracatı ucuzlatıp ithalatı pahalandırır. '
          'Sabit kur sisteminde hükümet kararıyla olur.',
      category: 'Döviz & Altın',
      relatedTerms: ['Döviz Kuru', 'Revalüasyon'],
    ),
    GlossaryTerm(
      term: 'Dolarizasyon',
      definition:
          'Yerleşiklerin tasarruflarını ve işlemlerini yabancı para '
          '(özellikle dolar) cinsinden yapma eğilimi. TL\'ye güven '
          'düşüklüğünün bir göstergesi.',
      category: 'Döviz & Altın',
      relatedTerms: ['Döviz Kuru', 'KKM'],
    ),
    GlossaryTerm(
      term: 'KKM (Kur Korumalı Mevduat)',
      definition:
          'TL mevduatın kur artışı kadar ek getiri sağlayan sistem. '
          'Dolarizasyonu önlemek için 2021\'de getirildi. '
          'Hazine\'ye maliyet yükler.',
      category: 'Döviz & Altın',
      relatedTerms: ['Dolarizasyon', 'Döviz Kuru'],
    ),
    GlossaryTerm(
      term: 'Altın Rezervi',
      definition:
          'Merkez bankasının kasasında tuttuğu altın miktarı. '
          'Uluslararası rezervlerin bir parçasıdır. '
          'Döviz krizlerinde güvence sağlar.',
      category: 'Döviz & Altın',
      relatedTerms: ['Brüt Rezerv', 'Net Rezerv'],
    ),

    // ── BÜYÜME & ÜRETİM ──
    GlossaryTerm(
      term: 'GSYİH (Gayri Safi Yurt İçi Hasıla)',
      definition:
          'Bir ülkede belirli bir dönemde üretilen tüm mal ve hizmetlerin '
          'toplam parasal değeri. Ekonominin büyüklüğünü ve büyüme hızını '
          'ölçen en temel gösterge.',
      category: 'Büyüme & Üretim',
      formula: 'GSYİH = C + I + G + (X - M)',
      relatedTerms: ['Büyüme Oranı', 'Resesyon', 'Kişi Başı GSYİH'],
      example: 'Türkiye GSYİH\'si 2023\'te yaklaşık 1.1 trilyon USD.',
    ),
    GlossaryTerm(
      term: 'Resesyon (Durgunluk)',
      definition:
          'GSYİH\'nin art arda 2 çeyrek (6 ay) daralması. '
          'İşsizlik artar, yatırımlar düşer, tüketim azalır.',
      category: 'Büyüme & Üretim',
      relatedTerms: ['GSYİH', 'Stagflasyon', 'Depresyon'],
    ),
    GlossaryTerm(
      term: 'Sanayi Üretim Endeksi',
      definition:
          'Sanayi sektörünün üretim hacmini ölçen endeks. '
          'GSYİH\'nin öncü göstergesidir. Aylık açıklanır.',
      category: 'Büyüme & Üretim',
      relatedTerms: ['GSYİH', 'Kapasite Kullanım Oranı', 'PMI'],
    ),
    GlossaryTerm(
      term: 'Kapasite Kullanım Oranı (KKO)',
      definition:
          'Sanayinin mevcut üretim kapasitesinin ne kadarını kullandığını '
          'gösteren oran. %80+ genellikle sağlıklı, %70 altı durgunluk sinyali.',
      category: 'Büyüme & Üretim',
      relatedTerms: ['Sanayi Üretim Endeksi', 'GSYİH'],
    ),
    GlossaryTerm(
      term: 'PMI (Purchasing Managers Index)',
      definition:
          'Satın alma yöneticileri endeksi. 50 üzeri genişleme, 50 altı '
          'daralma sinyali verir. Öncü gösterge olarak çok takip edilir.',
      category: 'Büyüme & Üretim',
      relatedTerms: ['Sanayi Üretim Endeksi', 'GSYİH'],
    ),

    // ── İSTİHDAM ──
    GlossaryTerm(
      term: 'İşsizlik Oranı',
      definition:
          'İş arayan ancak bulamayan kişilerin işgücüne oranı. '
          'Geniş tanımlı işsizlik iş aramaktan vazgeçenleri de kapsar.',
      category: 'İstihdam',
      formula: 'İşsizlik Oranı = (İşsiz Sayısı / İşgücü) × 100',
      relatedTerms: ['İşgücüne Katılım Oranı', 'İstihdam'],
    ),
    GlossaryTerm(
      term: 'İşgücüne Katılım Oranı',
      definition:
          'Çalışma çağındaki nüfusun ne kadarının iş piyasasında aktif olduğunu '
          'gösterir. Düşük katılım oranı "gizli işsizlik" anlamına gelebilir.',
      category: 'İstihdam',
      relatedTerms: ['İşsizlik Oranı', 'İstihdam'],
    ),
    GlossaryTerm(
      term: 'Tarım Dışı İstihdam',
      definition:
          'Tarım sektörü hariç ekonomideki toplam istihdam. '
          'Ekonominin dinamik kesimlerindeki iş gücünü yansıtır.',
      category: 'İstihdam',
      relatedTerms: ['İşsizlik Oranı', 'GSYİH'],
    ),

    // ── DIŞ TİCARET ──
    GlossaryTerm(
      term: 'Cari İşlemler Dengesi',
      definition:
          'Bir ülkenin dış dünyayla yaptığı tüm ekonomik işlemlerin net sonucu. '
          'Cari açık: ülke kazandığından fazlasını harcıyor demek. '
          'Dış borca bağımlılığı gösterir.',
      category: 'Dış Ticaret',
      formula: 'Cari Denge = İhracat - İthalat + Net Hizmetler + Net Transfer',
      relatedTerms: ['Dış Ticaret Dengesi', 'İhracat', 'İthalat'],
    ),
    GlossaryTerm(
      term: 'Dış Ticaret Açığı',
      definition:
          'İthalatın ihracattan fazla olması. Türkiye yapısal olarak '
          'dış ticaret açığı veren bir ülkedir (enerji ithalatı nedeniyle).',
      category: 'Dış Ticaret',
      relatedTerms: ['Cari İşlemler Dengesi', 'İhracat', 'İthalat'],
    ),
    GlossaryTerm(
      term: 'İhracat',
      definition:
          'Yurt içinde üretilen mal ve hizmetlerin yabancı ülkelere satılması. '
          'Döviz geliri sağlar, GSYİH\'ye pozitif katkı yapar.',
      category: 'Dış Ticaret',
      relatedTerms: ['İthalat', 'Dış Ticaret Açığı'],
    ),

    // ── FİNANSAL ──
    GlossaryTerm(
      term: 'BIST 100',
      definition:
          'Borsa İstanbul\'da işlem gören en büyük 100 şirketin '
          'hisse senedi endeksi. Türk borsasının genel performansını yansıtır.',
      category: 'Finansal',
      relatedTerms: ['Hisse Senedi', 'Piyasa Değeri'],
    ),
    GlossaryTerm(
      term: 'Tahvil Faizi (Gösterge)',
      definition:
          'Devletin borçlanma maliyetini gösteren referans tahvilin getirisi. '
          'Yüksek tahvil faizi = yüksek risk algısı veya sıkı para politikası.',
      category: 'Finansal',
      relatedTerms: ['Politika Faizi', 'CDS Primi'],
    ),
    GlossaryTerm(
      term: 'CDS Primi (Kredi Temerrüt Takası)',
      definition:
          'Bir ülkenin borçlarını ödeyememe riskinin fiyatı. '
          'CDS primi yükselirse ülke riski artıyor demektir. '
          '5 yıllık CDS en çok takip edilen vadelidir.',
      category: 'Finansal',
      relatedTerms: ['Tahvil Faizi', 'Kredi Notu'],
      example: 'CDS 300 baz puan ise, 10M\$ borcu sigortalamak yılda 300K\$ eder.',
    ),
    GlossaryTerm(
      term: 'Volatilite',
      definition:
          'Bir varlığın fiyatındaki dalgalanma miktarı. Yüksek volatilite = '
          'yüksek risk ve belirsizlik. Standart sapma ile ölçülür.',
      category: 'Finansal',
      relatedTerms: ['Risk', 'Standart Sapma'],
    ),
    GlossaryTerm(
      term: 'Likidite',
      definition:
          'Bir varlığın hızlı ve değer kaybetmeden nakde çevrilebilme kolaylığı. '
          'Nakit en likit varlıktır. Gayrimenkul düşük likiditedir.',
      category: 'Finansal',
      relatedTerms: ['Likidite Riski', 'Para Arzı'],
    ),

    // ── GÜVEN ENDEKSLERİ ──
    GlossaryTerm(
      term: 'Tüketici Güven Endeksi',
      definition:
          'Tüketicilerin ekonomik duruma ilişkin değerlendirme ve beklentilerini '
          'ölçen anket bazlı endeks. 100 üzeri iyimser, altı kötümser.',
      category: 'Güven Endeksleri',
      relatedTerms: ['Reel Kesim Güven Endeksi', 'PMI'],
    ),
    GlossaryTerm(
      term: 'Reel Kesim Güven Endeksi',
      definition:
          'İmalat sanayi firmalarının mevcut ve gelecek durum değerlendirmesi. '
          'TCMB tarafından aylık yayınlanır. 100 üzeri iyimser.',
      category: 'Güven Endeksleri',
      relatedTerms: ['Tüketici Güven Endeksi', 'Kapasite Kullanım Oranı'],
    ),

    // ── TEKNİK ANALİZ ──
    GlossaryTerm(
      term: 'SMA (Basit Hareketli Ortalama)',
      definition:
          'Belirli bir dönemdeki kapanış fiyatlarının aritmetik ortalaması. '
          'Trendin yönünü belirlemek için kullanılır. '
          'SMA(50) ve SMA(200) en yaygın kullanılan periyotlardır.',
      category: 'Teknik Analiz',
      formula: 'SMA(n) = (P₁ + P₂ + ... + Pₙ) / n',
      relatedTerms: ['EMA', 'Altın Kesişim', 'Ölüm Kesişimi'],
      example: '20 günlük SMA = son 20 günün ortalaması.',
    ),
    GlossaryTerm(
      term: 'EMA (Üstel Hareketli Ortalama)',
      definition:
          'Son verilere daha fazla ağırlık veren hareketli ortalama. '
          'SMA\'ya göre fiyat değişikliklerine daha hızlı tepki verir. '
          'Kısa vadeli analizlerde tercih edilir.',
      category: 'Teknik Analiz',
      formula: 'EMA = Fiyat × k + EMA(dün) × (1-k), k = 2/(n+1)',
      relatedTerms: ['SMA', 'MACD'],
    ),
    GlossaryTerm(
      term: 'Altın Kesişim (Golden Cross)',
      definition:
          'Kısa vadeli hareketli ortalamanın (ör: 50 gün) uzun vadeli '
          'hareketli ortalamayı (ör: 200 gün) aşağıdan yukarı kesmesi. '
          'Güçlü bir yükseliş sinyali olarak yorumlanır.',
      category: 'Teknik Analiz',
      relatedTerms: ['Ölüm Kesişimi', 'SMA', 'EMA'],
    ),
    GlossaryTerm(
      term: 'Ölüm Kesişimi (Death Cross)',
      definition:
          'Kısa vadeli hareketli ortalamanın uzun vadeli hareketli ortalamayı '
          'yukarıdan aşağı kesmesi. Düşüş sinyali olarak yorumlanır.',
      category: 'Teknik Analiz',
      relatedTerms: ['Altın Kesişim', 'SMA', 'EMA'],
    ),
    GlossaryTerm(
      term: 'Destek Seviyesi',
      definition:
          'Fiyatın düşerken alıcıların yoğunlaştığı ve düşüşün durma eğilimi '
          'gösterdiği fiyat seviyesi. Kırılırsa daha sert düşüş beklenir.',
      category: 'Teknik Analiz',
      relatedTerms: ['Direnç Seviyesi', 'Trend'],
    ),
    GlossaryTerm(
      term: 'Direnç Seviyesi',
      definition:
          'Fiyatın yükselirken satıcıların yoğunlaştığı ve yükselişin durma eğilimi '
          'gösterdiği fiyat seviyesi. Aşılırsa güçlü yükseliş beklenir.',
      category: 'Teknik Analiz',
      relatedTerms: ['Destek Seviyesi', 'Trend'],
    ),
    GlossaryTerm(
      term: 'RSI (Göreceli Güç Endeksi)',
      definition:
          '0-100 arasında değer alan momentum göstergesi. '
          '70 üzeri aşırı alım (overbought), 30 altı aşırı satım (oversold) '
          'bölgesi kabul edilir.',
      category: 'Teknik Analiz',
      formula: 'RSI = 100 - (100 / (1 + RS)), RS = Ort. Kazanç / Ort. Kayıp',
      relatedTerms: ['MACD', 'Momentum'],
    ),
    GlossaryTerm(
      term: 'MACD',
      definition:
          'Hareketli Ortalama Yakınsama Iraksama. İki EMA arasındaki farkı ölçer. '
          'Sinyal çizgisiyle kesişimleri alım/satım sinyali verir.',
      category: 'Teknik Analiz',
      formula: 'MACD = EMA(12) - EMA(26), Sinyal = EMA(9) of MACD',
      relatedTerms: ['EMA', 'RSI'],
    ),

    // ── GENEL ──
    GlossaryTerm(
      term: 'Baz Etkisi',
      definition:
          'Yıllık karşılaştırmada geçen yılın düşük/yüksek baz olmasının '
          'mevcut yılın değişim oranını abartması veya küçültmesi. '
          'Enflasyon yorumunda çok önemlidir.',
      category: 'Genel',
      relatedTerms: ['Enflasyon', 'TÜFE'],
      example:
          'Geçen yıl enflasyon %10 idiyse bu yıl %8 çıkması düşüş; '
          'ama geçen yıl %2 idiyse %8 ciddi artış.',
    ),
    GlossaryTerm(
      term: 'Korelasyon',
      definition:
          'İki değişken arasındaki istatistiksel ilişki. -1 ile +1 arasında değer alır. '
          '+1 mükemmel pozitif, -1 mükemmel negatif, 0 ilişki yok.',
      category: 'Genel',
      relatedTerms: ['Regresyon', 'R²'],
    ),
    GlossaryTerm(
      term: 'R² (Belirlilik Katsayısı)',
      definition:
          'Bir modelin veriyi ne kadar iyi açıkladığını gösteren ölçü. '
          '0-1 arasında; 1\'e yakınsa model çok açıklayıcı.',
      category: 'Genel',
      formula: 'R² = 1 - (SSres / SStot)',
      relatedTerms: ['Korelasyon', 'Regresyon'],
    ),
    GlossaryTerm(
      term: 'Baz Puan',
      definition:
          'Faiz oranlarındaki değişimi ifade eden birim. '
          '1 baz puan = %0.01. 100 baz puan = %1. '
          '"TCMB faizi 250 baz puan artırdı" = %2.5 artış.',
      category: 'Genel',
      relatedTerms: ['Politika Faizi'],
      example: 'Faiz %45\'ten %50\'ye çıktıysa 500 baz puan artmıştır.',
    ),
    GlossaryTerm(
      term: 'Carry Trade',
      definition:
          'Düşük faizli ülkeden borç alıp, yüksek faizli ülkede yatırım yapma stratejisi. '
          'Türkiye\'deki yüksek faiz carry trade\'i çeker, bu da TL\'ye talep yaratır.',
      category: 'Genel',
      relatedTerms: ['Döviz Kuru', 'Politika Faizi', 'Sıcak Para'],
    ),
    GlossaryTerm(
      term: 'Sıcak Para',
      definition:
          'Kısa vadeli yüksek getiri peşinde olan uluslararası spekülatif sermaye. '
          'Hızla girip çıkabilir, kur dalgalanmalarına yol açar.',
      category: 'Genel',
      relatedTerms: ['Carry Trade', 'Portföy Yatırımı'],
    ),
    GlossaryTerm(
      term: 'Swap',
      definition:
          'İki taraf arasında gelecekteki nakit akışlarının değişimine dayanan sözleşme. '
          'TCMB döviz swap ihaleleri ile bankacılık sektörüne likidite sağlar.',
      category: 'Genel',
      relatedTerms: ['Likidite', 'Repo', 'TCMB'],
    ),
    GlossaryTerm(
      term: 'Para Arzı (M2)',
      definition:
          'Ekonomideki toplam para miktarı. M1 (dolaşımdaki nakit + vadesiz mevduat) '
          'artı vadeli mevduatlar. TCMB politikalarından doğrudan etkilenir.',
      category: 'Genel',
      relatedTerms: ['Enflasyon', 'TCMB', 'Likidite'],
    ),
  ];

  /// Kategoriye göre filtreleme
  static List<GlossaryTerm> getByCategory(String category) {
    if (category == 'Tümü') return terms;
    return terms.where((t) => t.category == category).toList();
  }

  /// Arama fonksiyonu
  static List<GlossaryTerm> search(String query) {
    if (query.length < 2) return [];
    final q = query.toLowerCase();
    return terms.where((t) {
      return t.term.toLowerCase().contains(q) ||
          t.definition.toLowerCase().contains(q) ||
          t.relatedTerms.any((r) => r.toLowerCase().contains(q));
    }).toList();
  }
}