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
            i.id, i.name_tr, i.name_en, i.unit, i.evds_code, i.last_value, i.last_value_date,
            c.code as category_code, c.name_tr as category_name_tr, c.color as category_color,
            c.icon as category_icon
        FROM indicators i
        JOIN categories c ON c.id = i.category_id
        WHERE i.is_active = 1 AND i.last_value IS NOT NULL
        ORDER BY c.sort_order, i.id
    ");

    $data = $stmt->fetchAll();

    // Kategoriye göre grupla
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
        $grouped[$catCode]['indicators'][] = [
            'id' => $row['id'],
            'name' => $row['name_tr'],
            'value' => $row['last_value'],
            'date' => $row['last_value_date'],
            'unit' => $row['unit'],
        ];
    }

    return ['success' => true, 'data' => $grouped];
}

/**
 * GET /api.php?action=search&q=enflasyon
 * Gösterge adında arama yapar
 */
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