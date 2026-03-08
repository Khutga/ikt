<?php
/**
 * API Controller - Flutter'ın tüketeceği REST API
 * 
 * Basit bir router ile çalışır (framework kullanmadan).
 * Tüm yanıtlar JSON formatındadır.
 * 
 * Endpoints:
 * GET /api.php?action=categories              → Kategori listesi
 * GET /api.php?action=indicators&category=X    → Gösterge listesi (kategoriye göre filtrelenebilir)
 * GET /api.php?action=indicator&id=X           → Tek gösterge detayı + son değer
 * GET /api.php?action=data&id=X&start=Y&end=Z → Zaman serisi verisi
 * GET /api.php?action=compare&ids=1,2&start=Y  → Birden fazla gösterge karşılaştırma
 * GET /api.php?action=latest                   → Tüm göstergelerin son değerleri (dashboard özet)
 * GET /api.php?action=search&q=enflasyon       → Gösterge arama
 * POST /api.php?action=analyze                 → Python mikroservisine analiz isteği (proxy)
 */

// CORS & Temel Ayarlar
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

require_once __DIR__ . '/config/Database.php';
require_once __DIR__ . '/services/EvdsService.php';
require_once __DIR__ . '/services/WorldBankService.php';

// =========================================
// ROUTER
// =========================================

$action = $_GET['action'] ?? '';

try {
    $db = Database::getConnection();

    $response = match ($action) {
        'categories' => getCategories($db),
        'indicators' => getIndicators($db),
        'indicator' => getIndicatorDetail($db),
        'data' => getTimeSeriesData($db),
        'compare' => getComparisonData($db),
        'latest' => getLatestValues($db),
        'search' => searchIndicators($db),
        'analyze' => proxyToAnalysis(),
        'fetch' => triggerFetch(),
        'stats' => getSystemStats($db),
        'countries'       => getCountries(),
    'intl_indicators' => getIntlIndicators(),
    'intl_compare'    => getIntlComparison(),
    'intl_latest'     => getIntlLatest(),
    'sustainability'  => getSustainabilityDashboard(),
    'intl_fetch'      => triggerIntlFetch(),
    'intl_fetch_all'  => triggerIntlFetchAll(),
        default => [
            'error' => 'Geçersiz action',
            'available_actions' => [
                'categories',
                'indicators',
                'indicator',
                'data',
                'compare',
                'latest',
                'search',
                'analyze',
                'fetch',
                'stats'
            ]
        ],
    };

    echo json_encode($response, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Sunucu hatası',
        'message' => $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}

// =========================================
// ENDPOINT FONKSİYONLARI
// =========================================

/**
 * GET /api.php?action=categories
 * Tüm aktif kategorileri döner
 */
function getCategories(PDO $db): array
{
    $stmt = $db->query("
        SELECT c.*, COUNT(i.id) as indicator_count
        FROM categories c
        LEFT JOIN indicators i ON i.category_id = c.id AND i.is_active = 1
        WHERE c.is_active = 1
        GROUP BY c.id
        ORDER BY c.sort_order
    ");

    return ['success' => true, 'data' => $stmt->fetchAll()];
}

/**
 * GET /api.php?action=indicators
 * GET /api.php?action=indicators&category=1
 * GET /api.php?action=indicators&category_code=price_inflation
 * Gösterge listesini döner, opsiyonel kategoriye göre filtreler
 */
function getIndicators(PDO $db): array
{
    $categoryId = isset($_GET['category']) ? (int) $_GET['category'] : null;
    $categoryCode = $_GET['category_code'] ?? null;

    $sql = "
        SELECT i.*, c.name_tr as category_name_tr, c.name_en as category_name_en, c.code as category_code
        FROM indicators i
        JOIN categories c ON c.id = i.category_id
        WHERE i.is_active = 1
    ";
    $params = [];

    if ($categoryId) {
        $sql .= " AND i.category_id = ?";
        $params[] = $categoryId;
    } elseif ($categoryCode) {
        $sql .= " AND c.code = ?";
        $params[] = $categoryCode;
    }

    $sql .= " ORDER BY c.sort_order, i.id";

    $stmt = $db->prepare($sql);
    $stmt->execute($params);

    return ['success' => true, 'data' => $stmt->fetchAll()];
}

/**
 * GET /api.php?action=indicator&id=1
 * Tek gösterge detayı + son 5 değer
 */
function getIndicatorDetail(PDO $db): array
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if (!$id)
        return ['error' => 'id parametresi gerekli'];

    $stmt = $db->prepare("
        SELECT i.*, c.name_tr as category_name_tr, c.code as category_code
        FROM indicators i
        JOIN categories c ON c.id = i.category_id
        WHERE i.id = ?
    ");
    $stmt->execute([$id]);
    $indicator = $stmt->fetch();

    if (!$indicator)
        return ['error' => 'Gösterge bulunamadı'];

    // Son 5 değer
    $stmt = $db->prepare("
        SELECT date, value FROM data_points
        WHERE indicator_id = ?
        ORDER BY date DESC LIMIT 5
    ");
    $stmt->execute([$id]);
    $indicator['recent_values'] = $stmt->fetchAll();

    // Toplam veri noktası sayısı
    $stmt = $db->prepare("SELECT COUNT(*) as total FROM data_points WHERE indicator_id = ?");
    $stmt->execute([$id]);
    $indicator['total_data_points'] = $stmt->fetch()['total'];

    return ['success' => true, 'data' => $indicator];
}

/**
 * GET /api.php?action=data&id=1&start=2020-01-01&end=2024-12-31
 * GET /api.php?action=data&id=1&period=1y  (kısayol: 1y, 5y, 10y, ytd, max)
 * Zaman serisi verisi
 */
function getTimeSeriesData(PDO $db): array
{
    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if (!$id)
        return ['error' => 'id parametresi gerekli'];

    // Period kısayolları
    $period = $_GET['period'] ?? null;
    if ($period) {
        $endDate = date('Y-m-d');
        $startDate = match ($period) {
            '1m' => date('Y-m-d', strtotime('-1 month')),
            '3m' => date('Y-m-d', strtotime('-3 months')),
            '6m' => date('Y-m-d', strtotime('-6 months')),
            '1y' => date('Y-m-d', strtotime('-1 year')),
            '3y' => date('Y-m-d', strtotime('-3 years')),
            '5y' => date('Y-m-d', strtotime('-5 years')),
            '10y' => date('Y-m-d', strtotime('-10 years')),
            'ytd' => date('Y-01-01'),
            'max' => '2000-01-01',
            default => date('Y-m-d', strtotime('-1 year')),
        };
    } else {
        $startDate = $_GET['start'] ?? date('Y-m-d', strtotime('-1 year'));
        $endDate = $_GET['end'] ?? date('Y-m-d');
    }

    $stmt = $db->prepare("
        SELECT date, value 
        FROM data_points
        WHERE indicator_id = ? AND date BETWEEN ? AND ?
        ORDER BY date ASC
    ");
    $stmt->execute([$id, $startDate, $endDate]);
    $data = $stmt->fetchAll();

    // Gösterge bilgisi
    $stmt = $db->prepare("SELECT * FROM indicators WHERE id = ?");
    $stmt->execute([$id]);
    $indicator = $stmt->fetch();

    return [
        'success' => true,
        'indicator' => $indicator,
        'period' => ['start' => $startDate, 'end' => $endDate],
        'count' => count($data),
        'data' => $data,
    ];
}

/**
 * GET /api.php?action=compare&ids=1,2,3&start=2020-01-01&end=2024-12-31
 * GET /api.php?action=compare&ids=1,2&period=5y
 * Birden fazla göstergeyi karşılaştır
 */
function getComparisonData(PDO $db): array
{
    $idsParam = $_GET['ids'] ?? '';
    $ids = array_filter(array_map('intval', explode(',', $idsParam)));
    if (empty($ids))
        return ['error' => 'ids parametresi gerekli (virgülle ayrılmış ID\'ler)'];
    if (count($ids) > 5)
        return ['error' => 'En fazla 5 gösterge karşılaştırılabilir'];

    // Tarih aralığı (data endpoint'i ile aynı mantık)
    $period = $_GET['period'] ?? '5y';
    $endDate = date('Y-m-d');
    $startDate = match ($period) {
        '1y' => date('Y-m-d', strtotime('-1 year')),
        '3y' => date('Y-m-d', strtotime('-3 years')),
        '5y' => date('Y-m-d', strtotime('-5 years')),
        '10y' => date('Y-m-d', strtotime('-10 years')),
        'max' => '2000-01-01',
        default => date('Y-m-d', strtotime('-5 years')),
    };

    $result = [];
    $placeholders = str_repeat('?,', count($ids) - 1) . '?';

    // Gösterge bilgileri
    // Gösterge bilgileri
    $stmt = $db->prepare("SELECT * FROM indicators WHERE id IN ($placeholders)");
    $stmt->execute($ids);
    $rows = $stmt->fetchAll();

    $indicators = [];
    foreach ($rows as $row) {
        $indicators[$row['id']] = $row;
    }

    // Her gösterge için veri çek
    foreach ($ids as $id) {
        if (!isset($indicators[$id]))
            continue;

        $stmt = $db->prepare("
            SELECT date, value FROM data_points
            WHERE indicator_id = ? AND date BETWEEN ? AND ?
            ORDER BY date ASC
        ");
        $stmt->execute([$id, $startDate, $endDate]);

        $result[] = [
            'indicator' => $indicators[$id],
            'data' => $stmt->fetchAll(),
        ];
    }

    return [
        'success' => true,
        'period' => ['start' => $startDate, 'end' => $endDate],
        'series' => $result,
    ];
}

/**
 * GET /api.php?action=latest
 * Dashboard özet: Tüm göstergelerin son değerleri
 */
function getLatestValues(PDO $db): array
{
    $stmt = $db->query("
        SELECT 
            i.id, i.name_tr, i.name_en, i.unit, i.evds_code, 
            i.last_value, i.last_value_date,
            c.code as category_code, c.name_tr as category_name_tr, 
            c.color as category_color, c.icon as category_icon
        FROM indicators i
        JOIN categories c ON c.id = i.category_id
        WHERE i.is_active = 1 AND i.last_value IS NOT NULL
        ORDER BY c.sort_order, i.id
    ");

    $data = $stmt->fetchAll();

    // Her gösterge için sparkline + change hesapla
    $sparkStmt = $db->prepare("
        SELECT value FROM data_points 
        WHERE indicator_id = ? 
        ORDER BY date DESC 
        LIMIT 30
    ");

    $grouped = [];
    foreach ($data as $row) {
        $catCode = $row['category_code'];
        if (!isset($grouped[$catCode])) {
            $grouped[$catCode] = [
                'category' => $row['category_name_tr'],
                'color' => $row['category_color'],
                'icon' => $row['category_icon'],
                'indicators' => [],
            ];
        }

        // Sparkline: son 30 değer (eski→yeni sırada)
        $sparkStmt->execute([$row['id']]);
        $sparkValues = $sparkStmt->fetchAll(PDO::FETCH_COLUMN);
        $sparkValues = array_reverse($sparkValues); // eski→yeni

        // Değişim yüzdesi: son iki değer arasında
        $changePct = null;
        if (count($sparkValues) >= 2) {
            $last = (float) end($sparkValues);
            $prev = (float) $sparkValues[count($sparkValues) - 2];
            if ($prev != 0) {
                $changePct = round(($last - $prev) / abs($prev) * 100, 2);
            }
        }

        $grouped[$catCode]['indicators'][] = [
            'id' => $row['id'],
            'name' => $row['name_tr'],
            'value' => $row['last_value'],
            'date' => $row['last_value_date'],
            'unit' => $row['unit'],
            'sparkline' => $sparkValues,
            'change_pct' => $changePct,
        ];
    }

    return ['success' => true, 'data' => $grouped];
}



function searchIndicators(PDO $db): array
{
    $query = $_GET['q'] ?? '';
    if (strlen($query) < 2)
        return ['error' => 'En az 2 karakter girin'];

    $searchTerm = '%' . $query . '%';
    $stmt = $db->prepare("
        SELECT i.id, i.name_tr, i.name_en, i.unit, i.evds_code, i.last_value, i.last_value_date,
               c.name_tr as category_name_tr, c.code as category_code
        FROM indicators i
        JOIN categories c ON c.id = i.category_id
        WHERE i.is_active = 1 AND (i.name_tr LIKE ? OR i.name_en LIKE ? OR i.evds_code LIKE ?)
        ORDER BY c.sort_order, i.id
        LIMIT 20
    ");
    $stmt->execute([$searchTerm, $searchTerm, $searchTerm]);

    return ['success' => true, 'data' => $stmt->fetchAll()];
}

/**
 * POST /api.php?action=analyze
 * Python mikroservisine analiz isteğini proxy'ler
 * 
 * Body: {
 *   "type": "correlation|trend|statistics",
 *   "indicator_ids": [1, 2],
 *   "period": "5y",
 *   "params": {}
 * }
 */
function proxyToAnalysis(): array
{
    $config = require __DIR__ . '/config/config.php';
    $pythonUrl = $config['python_service']['base_url'];
    $timeout = $config['python_service']['timeout'];

    $body = file_get_contents('php://input');
    $requestData = json_decode($body, true);

    if (!$requestData) {
        return ['error' => 'Geçersiz JSON body'];
    }

    // Önce cache'i kontrol et
    $db = Database::getConnection();
    $cacheKey = md5(json_encode($requestData));

    $stmt = $db->prepare("
        SELECT result FROM analysis_cache 
        WHERE cache_key = ? AND expires_at > NOW()
    ");
    $stmt->execute([$cacheKey]);
    $cached = $stmt->fetch();

    if ($cached) {
        $result = json_decode($cached['result'], true);
        $result['from_cache'] = true;
        return ['success' => true, 'data' => $result];
    }

    // Veriyi Python'a göndermeden önce DB'den çek
    $analysisData = prepareDataForAnalysis($db, $requestData);
    $requestData['series_data'] = $analysisData;

    // Python mikroservisine HTTP isteği
    $ch = curl_init($pythonUrl . '/analyze');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST => true,
        CURLOPT_POSTFIELDS => json_encode($requestData),
        CURLOPT_TIMEOUT => $timeout,
        CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
    ]);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($httpCode !== 200 || !$response) {
        return ['error' => 'Analiz servisi yanıt vermedi', 'http_code' => $httpCode];
    }

    $result = json_decode($response, true);

    // Cache'e yaz
    $cacheTtl = $config['cache']['analysis_ttl'];
    $stmt = $db->prepare("
        INSERT INTO analysis_cache (cache_key, analysis_type, indicator_ids, parameters, result, expires_at)
        VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? SECOND))
        ON DUPLICATE KEY UPDATE result = VALUES(result), expires_at = VALUES(expires_at)
    ");
    $stmt->execute([
        $cacheKey,
        $requestData['type'] ?? 'unknown',
        json_encode($requestData['indicator_ids'] ?? []),
        json_encode($requestData['params'] ?? []),
        json_encode($result),
        $cacheTtl,
    ]);

    return ['success' => true, 'data' => $result];
}

/**
 * Analiz için gerekli veriyi DB'den çekip Python'a gönderilecek formata getirir
 */
function prepareDataForAnalysis(PDO $db, array $request): array
{
    $ids = $request['indicator_ids'] ?? [];
    $period = $request['period'] ?? '5y';

    $endDate = date('Y-m-d');
    $startDate = match ($period) {
        '1y' => date('Y-m-d', strtotime('-1 year')),
        '3y' => date('Y-m-d', strtotime('-3 years')),
        '5y' => date('Y-m-d', strtotime('-5 years')),
        '10y' => date('Y-m-d', strtotime('-10 years')),
        default => date('Y-m-d', strtotime('-5 years')),
    };

    $seriesData = [];
    foreach ($ids as $id) {
        $stmt = $db->prepare("
            SELECT i.name_tr, i.evds_code, i.unit FROM indicators i WHERE i.id = ?
        ");
        $stmt->execute([$id]);
        $indicator = $stmt->fetch();

        $stmt = $db->prepare("
            SELECT date, value FROM data_points
            WHERE indicator_id = ? AND date BETWEEN ? AND ?
            ORDER BY date ASC
        ");
        $stmt->execute([$id, $startDate, $endDate]);

        $seriesData[] = [
            'indicator_id' => $id,
            'name' => $indicator['name_tr'] ?? "Gösterge #$id",
            'code' => $indicator['evds_code'] ?? '',
            'unit' => $indicator['unit'] ?? '',
            'data' => $stmt->fetchAll(),
        ];
    }

    return $seriesData;
}

/**
 * GET /api.php?action=fetch&id=1  (tek gösterge)
 * GET /api.php?action=fetch&all=1  (tüm göstergeler)
 * Manuel veri çekme tetikleyici (admin/debug amaçlı)
 */
function triggerFetch(): array
{
    $evds = new EvdsService();

    if (isset($_GET['all'])) {
        return ['success' => true, 'results' => $evds->fetchAllActive()];
    }

    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;
    if (!$id)
        return ['error' => 'id veya all parametresi gerekli'];

    return $evds->fetchIndicatorData($id);
}

/**
 * GET /api.php?action=stats
 * Sistem istatistikleri
 */
function getSystemStats(PDO $db): array
{
    $stats = [];

    // Toplam gösterge sayısı
    $stats['total_indicators'] = $db->query("SELECT COUNT(*) FROM indicators WHERE is_active = 1")->fetchColumn();

    // Toplam veri noktası
    $stats['total_data_points'] = $db->query("SELECT COUNT(*) FROM data_points")->fetchColumn();

    // Son veri çekme
    $stats['last_fetch'] = $db->query("SELECT MAX(created_at) FROM fetch_logs WHERE status = 'success'")->fetchColumn();

    // Bugünkü hata sayısı
    $stats['todays_errors'] = $db->query(
        "SELECT COUNT(*) FROM fetch_logs WHERE status = 'error' AND DATE(created_at) = CURDATE()"
    )->fetchColumn();

    // En eski ve en yeni veri tarihi
    $stats['data_range'] = [
        'oldest' => $db->query("SELECT MIN(date) FROM data_points")->fetchColumn(),
        'newest' => $db->query("SELECT MAX(date) FROM data_points")->fetchColumn(),
    ];

    return ['success' => true, 'data' => $stats];
}

function getCountries(): array
{
    $wb = new WorldBankService();
    $countries = $wb->getCountries();

    return ['success' => true, 'data' => $countries];
}

/**
 * GET ?action=intl_indicators
 * GET ?action=intl_indicators&category=sustainability
 * Uluslararası göstergeleri listeler
 */
function getIntlIndicators(): array
{
    $wb = new WorldBankService();
    $categoryCode = $_GET['category'] ?? null;
    $indicators = $wb->getIndicators($categoryCode);

    return ['success' => true, 'data' => $indicators];
}

/**
 * GET ?action=intl_compare&indicator=1&countries=TUR,USA,DEU&start=2010&end=2024
 * Ülkeler arası kıyaslama verisi
 */
function getIntlComparison(): array
{
    $indicatorId = isset($_GET['indicator']) ? (int) $_GET['indicator'] : 0;
    if (!$indicatorId) return ['error' => 'indicator parametresi gerekli'];

    $countriesParam = $_GET['countries'] ?? 'TUR,USA,DEU';
    $countryCodes = array_filter(array_map('trim', explode(',', $countriesParam)));

    if (empty($countryCodes)) return ['error' => 'countries parametresi gerekli'];
    if (count($countryCodes) > 10) return ['error' => 'En fazla 10 ülke karşılaştırılabilir'];

    $startYear = isset($_GET['start']) ? (int) $_GET['start'] : 2000;
    $endYear = isset($_GET['end']) ? (int) $_GET['end'] : (int) date('Y');

    $wb = new WorldBankService();
    return $wb->getComparisonData($indicatorId, $countryCodes, $startYear, $endYear);
}

/**
 * GET ?action=intl_latest&countries=TUR,USA,DEU
 * Her ülkenin her gösterge için son değerini döner
 */
function getIntlLatest(): array
{
    $db = Database::getConnection();

    $countriesParam = $_GET['countries'] ?? '';
    $countryFilter = '';
    $params = [];

    if ($countriesParam) {
        $codes = array_filter(array_map('trim', explode(',', $countriesParam)));
        $placeholders = str_repeat('?,', count($codes) - 1) . '?';
        $countryFilter = "AND c.iso_code IN ($placeholders)";
        $params = $codes;
    }

    $stmt = $db->prepare("
        SELECT 
            ii.id as indicator_id,
            ii.name_tr as indicator_name,
            ii.unit,
            ii.source_type,
            c.iso_code,
            c.name_tr as country_name,
            c.flag_emoji,
            idp.value,
            idp.date,
            cat.code as category_code,
            cat.name_tr as category_name
        FROM international_data_points idp
        JOIN international_indicators ii ON ii.id = idp.intl_indicator_id
        JOIN countries c ON c.id = idp.country_id
        JOIN categories cat ON cat.id = ii.category_id
        WHERE ii.is_active = 1
          AND c.is_active = 1
          $countryFilter
          AND idp.date = (
              SELECT MAX(idp2.date)
              FROM international_data_points idp2
              WHERE idp2.intl_indicator_id = idp.intl_indicator_id
                AND idp2.country_id = idp.country_id
          )
        ORDER BY cat.sort_order, ii.id, c.sort_order
    ");
    $stmt->execute($params);
    $rows = $stmt->fetchAll();

    // Göstergeye göre grupla
    $grouped = [];
    foreach ($rows as $row) {
        $indId = $row['indicator_id'];
        if (!isset($grouped[$indId])) {
            $grouped[$indId] = [
                'indicator' => [
                    'id' => $indId,
                    'name_tr' => $row['indicator_name'],
                    'unit' => $row['unit'],
                    'category' => $row['category_name'],
                    'category_code' => $row['category_code'],
                ],
                'countries' => [],
            ];
        }
        $grouped[$indId]['countries'][] = [
            'iso_code' => $row['iso_code'],
            'name_tr' => $row['country_name'],
            'flag_emoji' => $row['flag_emoji'],
            'value' => $row['value'],
            'date' => $row['date'],
        ];
    }

    return ['success' => true, 'data' => array_values($grouped)];
}

/**
 * GET ?action=sustainability&countries=TUR,USA,DEU
 * Sürdürülebilirlik dashboard özeti — Türkiye odaklı, kıyaslamalı
 */
function getSustainabilityDashboard(): array
{
    $db = Database::getConnection();

    $countriesParam = $_GET['countries'] ?? 'TUR,USA,DEU,CHN,BRA';
    $codes = array_filter(array_map('trim', explode(',', $countriesParam)));
    $placeholders = str_repeat('?,', count($codes) - 1) . '?';

    // Sürdürülebilirlik kategorisindeki göstergeler
    $stmt = $db->prepare("
        SELECT 
            ii.id, ii.name_tr, ii.unit, ii.source_code,
            c.iso_code, c.name_tr as country_name, c.flag_emoji,
            idp.value, idp.date
        FROM international_data_points idp
        JOIN international_indicators ii ON ii.id = idp.intl_indicator_id
        JOIN countries c ON c.id = idp.country_id
        JOIN categories cat ON cat.id = ii.category_id
        WHERE cat.code = 'sustainability'
          AND ii.is_active = 1
          AND c.iso_code IN ($placeholders)
          AND idp.date = (
              SELECT MAX(idp2.date)
              FROM international_data_points idp2
              WHERE idp2.intl_indicator_id = idp.intl_indicator_id
                AND idp2.country_id = idp.country_id
          )
        ORDER BY ii.id, c.sort_order
    ");
    $stmt->execute($codes);
    $rows = $stmt->fetchAll();

    // Gösterge bazlı grupla
    $indicators = [];
    foreach ($rows as $row) {
        $indId = $row['id'];
        if (!isset($indicators[$indId])) {
            $indicators[$indId] = [
                'name_tr' => $row['name_tr'],
                'unit' => $row['unit'],
                'countries' => [],
            ];
        }
        $indicators[$indId]['countries'][$row['iso_code']] = [
            'name' => $row['country_name'],
            'flag' => $row['flag_emoji'],
            'value' => $row['value'],
            'date' => $row['date'],
        ];
    }

    // Türkiye'nin pozisyonu her göstergede
    $turkeyRankings = [];
    foreach ($indicators as $indId => $ind) {
        $values = [];
        foreach ($ind['countries'] as $iso => $data) {
            $values[$iso] = (float) $data['value'];
        }
        arsort($values);
        $rank = array_search('TUR', array_keys($values));
        $turkeyRankings[$indId] = [
            'rank' => $rank !== false ? $rank + 1 : null,
            'total' => count($values),
            'value' => $values['TUR'] ?? null,
        ];
    }

    return [
        'success' => true,
        'data' => [
            'indicators' => array_values($indicators),
            'turkey_rankings' => $turkeyRankings,
            'countries_compared' => $codes,
        ],
    ];
}

/**
 * POST ?action=intl_fetch&indicator=1
 * Manuel uluslararası veri çekme
 */
function triggerIntlFetch(): array
{
    $id = isset($_GET['indicator']) ? (int) $_GET['indicator'] : 0;
    if (!$id) return ['error' => 'indicator parametresi gerekli'];

    $wb = new WorldBankService();
    return $wb->fetchIndicatorData($id);
}

/**
 * POST ?action=intl_fetch_all
 * Tüm uluslararası göstergeleri güncelle
 */
function triggerIntlFetchAll(): array
{
    $wb = new WorldBankService();
    return ['success' => true, 'results' => $wb->fetchAllActive()];
}