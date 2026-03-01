
CREATE TABLE categories (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    code VARCHAR(50) NOT NULL UNIQUE COMMENT 'Dahili kategori kodu',
    name_tr VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    icon VARCHAR(50) DEFAULT NULL COMMENT 'Flutter ikonu için tanımlayıcı',
    color VARCHAR(7) DEFAULT NULL COMMENT 'Hex renk kodu (#FF5733)',
    sort_order TINYINT UNSIGNED DEFAULT 0,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_active_sort (is_active, sort_order)
) ENGINE=InnoDB COMMENT='Gösterge kategorileri';

-- ============================================
-- 2. GÖSTERGELER (INDICATORS) TABLOSU
-- ============================================
-- Her bir ekonomik seri burada tanımlanır
-- Yeni gösterge eklemek = bu tabloya bir satır eklemek

CREATE TABLE indicators (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    category_id INT UNSIGNED NOT NULL,
    evds_code VARCHAR(100) NOT NULL UNIQUE COMMENT 'TCMB EVDS seri kodu (ör: TP.FG.J0)',
    name_tr VARCHAR(255) NOT NULL,
    name_en VARCHAR(255) NOT NULL,
    description_tr TEXT DEFAULT NULL,
    description_en TEXT DEFAULT NULL,
    unit VARCHAR(50) NOT NULL COMMENT 'Birim: %, TL, USD, endeks, milyon USD...',
    frequency ENUM('daily','weekly','monthly','quarterly','yearly') NOT NULL DEFAULT 'monthly',
    source VARCHAR(100) DEFAULT 'TCMB' COMMENT 'Veri kaynağı: TCMB, TÜİK, BDDK...',
    decimal_places TINYINT UNSIGNED DEFAULT 2,
    is_active TINYINT(1) DEFAULT 1,
    last_fetched_at TIMESTAMP NULL DEFAULT NULL COMMENT 'Son veri çekme zamanı',
    last_value DECIMAL(20,6) DEFAULT NULL COMMENT 'Hızlı erişim için son değer cache',
    last_value_date DATE DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT,
    INDEX idx_category (category_id),
    INDEX idx_active (is_active),
    INDEX idx_frequency (frequency),
    INDEX idx_last_fetched (last_fetched_at)
) ENGINE=InnoDB COMMENT='Ekonomik göstergeler / veri serileri';

-- ============================================
-- 3. VERİ NOKTALARI (DATA POINTS) TABLOSU
-- ============================================
-- Tüm zaman serisi verileri burada saklanır
-- Bu tablonun performansı kritik → uygun indeksler

CREATE TABLE data_points (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    indicator_id INT UNSIGNED NOT NULL,
    date DATE NOT NULL,
    value DECIMAL(20,6) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE CASCADE,
    UNIQUE INDEX idx_indicator_date (indicator_id, date),
    INDEX idx_date (date)
) ENGINE=InnoDB COMMENT='Zaman serisi veri noktaları';

-- ============================================
-- 4. VERİ ÇEKME LOG TABLOSU
-- ============================================
-- Her API çağrısının kaydını tutar (debug & monitoring)

CREATE TABLE fetch_logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    indicator_id INT UNSIGNED DEFAULT NULL,
    fetch_type ENUM('single','bulk','category') NOT NULL DEFAULT 'single',
    status ENUM('success','error','partial') NOT NULL,
    records_fetched INT UNSIGNED DEFAULT 0,
    records_inserted INT UNSIGNED DEFAULT 0,
    error_message TEXT DEFAULT NULL,
    execution_time_ms INT UNSIGNED DEFAULT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (indicator_id) REFERENCES indicators(id) ON DELETE SET NULL,
    INDEX idx_status (status),
    INDEX idx_created (created_at)
) ENGINE=InnoDB COMMENT='Veri çekme işlem logları';

-- ============================================
-- 5. ANALİZ CACHE TABLOSU
-- ============================================
-- Python mikroservisinden dönen analiz sonuçlarını cache'ler
-- Aynı analizi tekrar tekrar hesaplamamak için

CREATE TABLE analysis_cache (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    cache_key VARCHAR(255) NOT NULL UNIQUE COMMENT 'Hash key: indicator_ids + period + type',
    analysis_type ENUM('correlation','moving_avg','trend','comparison','statistics') NOT NULL,
    indicator_ids JSON NOT NULL COMMENT 'Analiz edilen gösterge ID listesi',
    parameters JSON DEFAULT NULL COMMENT 'Analiz parametreleri',
    result JSON NOT NULL COMMENT 'Analiz sonucu',
    expires_at TIMESTAMP NOT NULL COMMENT 'Cache süresi',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_cache_key (cache_key),
    INDEX idx_expires (expires_at),
    INDEX idx_type (analysis_type)
) ENGINE=InnoDB COMMENT='Analiz sonucu cache';

-- ============================================
-- 6. KULLANICI FAVORİLERİ (opsiyonel - Faz 4)
-- ============================================

CREATE TABLE user_favorites (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL COMMENT 'Flutter cihaz kimliği',
    indicator_ids JSON NOT NULL COMMENT 'Favori gösterge listesi',
    dashboard_config JSON DEFAULT NULL COMMENT 'Kullanıcı dashboard ayarları',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE INDEX idx_device (device_id)
) ENGINE=InnoDB COMMENT='Kullanıcı favori göstergeleri';

-- ============================================
-- BAŞLANGIÇ VERİLERİ (SEED DATA)
-- ============================================

-- Kategoriler
INSERT INTO categories (code, name_tr, name_en, icon, color, sort_order) VALUES
('price_inflation',   'Fiyat & Enflasyon',      'Price & Inflation',     'trending_up',     '#FF6B6B', 1),
('monetary_policy',   'Para Politikası',         'Monetary Policy',       'account_balance',  '#4ECDC4', 2),
('exchange_rates',    'Döviz & Altın',           'Exchange Rates & Gold', 'currency_exchange', '#45B7D1', 3),
('growth_production', 'Büyüme & Üretim',         'Growth & Production',   'factory',          '#96CEB4', 4),
('employment',        'İstihdam',                'Employment',            'people',           '#FFEAA7', 5),
('foreign_trade',     'Dış Ticaret',             'Foreign Trade',         'local_shipping',   '#DDA0DD', 6),
('financial',         'Finansal Göstergeler',    'Financial Indicators',  'show_chart',       '#98D8C8', 7),
('confidence',        'Güven Endeksleri',        'Confidence Indices',    'psychology',       '#F7DC6F', 8);

-- Göstergeler - FİYAT & ENFLASYON
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(1, 'TP.FG.J0',         'TÜFE (Genel)',                          'CPI (General)',                      '%',     'monthly', 'TÜİK',  2),
(1, 'TP.FG.J1',         'TÜFE - Gıda ve Alkolsüz İçecekler',    'CPI - Food & Non-Alcoholic',         '%',     'monthly', 'TÜİK',  2),
(1, 'TP.FG.TG2',        'ÜFE (Genel)',                           'PPI (General)',                      '%',     'monthly', 'TÜİK',  2),
(1, 'TP.ENFBEK.PKA12ENF','Enflasyon Beklentisi (12 Ay)',         'Inflation Expectations (12M)',        '%',     'monthly', 'TCMB',  2);

-- Göstergeler - PARA POLİTİKASI
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(2, 'TP.PF.ON.AGR',     'Politika Faizi (Haftalık Repo)',        'Policy Rate (Weekly Repo)',           '%',     'daily',   'TCMB',  2),
(2, 'TP.AOFOZ.ON',      'Ağırlıklı Ortalama Fonlama Maliyeti',  'Weighted Avg Funding Cost',           '%',     'daily',   'TCMB',  2),
(2, 'TP.TIG.ON02',      'Gecelik Faiz (Borç Verme)',             'Overnight Rate (Lending)',            '%',     'daily',   'TCMB',  2);

-- Göstergeler - DÖVİZ & ALTIN
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(3, 'TP.DK.USD.A.YTL',  'USD/TRY (Döviz Alış)',                 'USD/TRY (Buying)',                   'TL',    'daily',   'TCMB',  4),
(3, 'TP.DK.EUR.A.YTL',  'EUR/TRY (Döviz Alış)',                 'EUR/TRY (Buying)',                   'TL',    'daily',   'TCMB',  4),
(3, 'TP.DK.GBP.A.YTL',  'GBP/TRY (Döviz Alış)',                 'GBP/TRY (Buying)',                   'TL',    'daily',   'TCMB',  4),
(3, 'TP.DK.CHF.A.YTL',  'CHF/TRY (Döviz Alış)',                 'CHF/TRY (Buying)',                   'TL',    'daily',   'TCMB',  4),
(3, 'TP.DK.JPY.A.YTL',  'JPY/TRY (Döviz Alış)',                 'JPY/TRY (Buying)',                   'TL',    'daily',   'TCMB',  4);

-- Göstergeler - BÜYÜME & ÜRETİM
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(4, 'TP.GSYIH01.GY.CF', 'GSYİH (Cari Fiyatlarla)',              'GDP (Current Prices)',               'milyon TL', 'quarterly', 'TÜİK', 0),
(4, 'TP.SANAYREV4.Y1',  'Sanayi Üretim Endeksi',                'Industrial Production Index',         'endeks',    'monthly',   'TÜİK', 1),
(4, 'TP.KKO2.GENEL',    'Kapasite Kullanım Oranı',              'Capacity Utilization Rate',           '%',         'monthly',   'TCMB', 1);

-- Göstergeler - İSTİHDAM
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(5, 'TP.ISG10.GENEL',   'İşsizlik Oranı',                       'Unemployment Rate',                   '%',     'monthly', 'TÜİK',  1),
(5, 'TP.ISG10.ISTGUC',  'İşgücüne Katılım Oranı',               'Labor Force Participation Rate',      '%',     'monthly', 'TÜİK',  1);

-- Göstergeler - DIŞ TİCARET
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(6, 'TP.DIS.IHRAC.YTL', 'İhracat (TL)',                          'Exports (TL)',                       'milyon TL',  'monthly', 'TÜİK', 0),
(6, 'TP.DIS.ITHAL.YTL', 'İthalat (TL)',                          'Imports (TL)',                       'milyon TL',  'monthly', 'TÜİK', 0),
(6, 'TP.ODEMGOS.CARIISLEM', 'Cari İşlemler Dengesi',             'Current Account Balance',            'milyon USD', 'monthly', 'TCMB', 0);

-- Göstergeler - FİNANSAL
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(7, 'TP.MK.F.BIST100-TL', 'BIST 100 Endeksi',                   'BIST 100 Index',                     'endeks', 'daily',   'BIST',  2),
(7, 'TP.GOVBOND.05Y',     'Gösterge Tahvil Faizi (5 Yıl)',       'Benchmark Bond Yield (5Y)',          '%',      'daily',   'TCMB',  2);

-- Göstergeler - GÜVEN ENDEKSLERİ
INSERT INTO indicators (category_id, evds_code, name_tr, name_en, unit, frequency, source, decimal_places) VALUES
(8, 'TP.TG2.Y01',       'Tüketici Güven Endeksi',               'Consumer Confidence Index',            'endeks', 'monthly', 'TÜİK', 1),
(8, 'TP.RKGS.GE',       'Reel Kesim Güven Endeksi',             'Real Sector Confidence Index',         'endeks', 'monthly', 'TCMB', 1);