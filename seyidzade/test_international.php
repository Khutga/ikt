<?php
/**
 * test_international.php - Uluslararası Veri Tanılama Aracı
 * 
 * Tarayıcıdan çalıştırın: https://seyidzade.sbs/apis/ikt/test_international.php
 * 
 * Kontrol eder:
 * 1. countries tablosu var mı ve dolu mu?
 * 2. international_indicators tablosu var mı ve dolu mu?
 * 3. international_data_points tablosunda veri var mı?
 * 4. Dünya Bankası API'sine erişilebiliyor mu?
 * 5. Veri çekme test (tek gösterge, tek ülke)
 */

header('Content-Type: text/html; charset=utf-8');

require_once __DIR__ . '/config/Database.php';

$checks = [];
$db = null;

// ─── 1. Veritabanı bağlantısı ───
try {
    $db = Database::getConnection();
    $checks[] = ['✅', 'DB Bağlantı', 'Veritabanına başarıyla bağlanıldı'];
} catch (Exception $e) {
    $checks[] = ['❌', 'DB Bağlantı', 'HATA: ' . $e->getMessage()];
    outputHtml($checks);
    exit;
}

// ─── 2. Tablo kontrolleri ───
$tables = ['countries', 'international_indicators', 'international_data_points', 'categories', 'external_fetch_logs'];
foreach ($tables as $table) {
    try {
        $count = $db->query("SELECT COUNT(*) FROM `$table`")->fetchColumn();
        $icon = $count > 0 ? '✅' : '⚠️';
        $checks[] = [$icon, "Tablo: $table", "$count kayıt"];
    } catch (Exception $e) {
        $checks[] = ['❌', "Tablo: $table", 'TABLO YOK! Migration çalıştırılmamış: ' . $e->getMessage()];
    }
}

// ─── 3. Kategori kontrolü (sustainability var mı?) ───
try {
    $stmt = $db->query("SELECT id, code, name_tr FROM categories WHERE code = 'sustainability'");
    $cat = $stmt->fetch();
    if ($cat) {
        $checks[] = ['✅', 'Sürdürülebilirlik Kategorisi', "ID: {$cat['id']} - {$cat['name_tr']}"];
    } else {
        $checks[] = ['❌', 'Sürdürülebilirlik Kategorisi', 'Bulunamadı! seed_international_data.sql çalıştırın'];
    }
} catch (Exception $e) {
    $checks[] = ['❌', 'Kategori Sorgu', $e->getMessage()];
}

// ─── 4. Ülke listesi ───
try {
    $stmt = $db->query("SELECT iso_code, name_tr, flag_emoji FROM countries WHERE is_active = 1 ORDER BY sort_order LIMIT 10");
    $countries = $stmt->fetchAll();
    if (count($countries) > 0) {
        $list = array_map(fn($c) => "{$c['flag_emoji']} {$c['name_tr']} ({$c['iso_code']})", $countries);
        $checks[] = ['✅', 'Ülkeler', count($countries) . ' aktif ülke: ' . implode(', ', array_slice($list, 0, 5)) . '...'];
    } else {
        $checks[] = ['❌', 'Ülkeler', 'Hiç ülke yok! seed_international_data.sql çalıştırın'];
    }
} catch (Exception $e) {
    $checks[] = ['❌', 'Ülke Sorgu', $e->getMessage()];
}

// ─── 5. Uluslararası göstergeler ───
try {
    $stmt = $db->query("SELECT id, source_code, name_tr, source_type FROM international_indicators WHERE is_active = 1");
    $indicators = $stmt->fetchAll();
    if (count($indicators) > 0) {
        $list = array_map(fn($i) => "{$i['name_tr']} [{$i['source_code']}]", $indicators);
        $checks[] = ['✅', 'Uluslararası Göstergeler', count($indicators) . ' gösterge: ' . implode(', ', array_slice($list, 0, 3)) . '...'];
    } else {
        $checks[] = ['❌', 'Uluslararası Göstergeler', 'Hiç gösterge yok! seed_international_data.sql çalıştırın'];
    }
} catch (Exception $e) {
    $checks[] = ['❌', 'Gösterge Sorgu', $e->getMessage()];
}

// ─── 6. Uluslararası veri noktaları ───
try {
    $count = $db->query("SELECT COUNT(*) FROM international_data_points")->fetchColumn();
    if ($count > 0) {
        // Ülke başına kaç veri var?
        $stmt = $db->query("
            SELECT c.name_tr, c.iso_code, COUNT(*) as cnt 
            FROM international_data_points idp 
            JOIN countries c ON c.id = idp.country_id 
            GROUP BY c.id 
            ORDER BY cnt DESC 
            LIMIT 5
        ");
        $breakdown = $stmt->fetchAll();
        $details = array_map(fn($b) => "{$b['name_tr']}: {$b['cnt']}", $breakdown);
        $checks[] = ['✅', 'Uluslararası Veri', "$count toplam veri noktası. " . implode(', ', $details)];
    } else {
        $checks[] = ['❌', 'Uluslararası Veri', 
            'HİÇ VERİ YOK! Bu ana sorun. Çözüm seçenekleri:<br>' .
            '&nbsp;&nbsp;A) <code>php fetch_international.php --verbose</code> çalıştırın (World Bank API\'den çeker)<br>' .
            '&nbsp;&nbsp;B) <code>seed_international_data.sql</code> dosyasını import edin (hazır örnek veri)'
        ];
    }
} catch (Exception $e) {
    $checks[] = ['❌', 'Veri Noktası Sorgu', $e->getMessage()];
}

// ─── 7. Dünya Bankası API testi ───
$checks[] = ['ℹ️', 'Dünya Bankası API Test', 'Test ediliyor...'];
try {
    $testUrl = 'https://api.worldbank.org/v2/country/TUR/indicator/FP.CPI.TOTL.ZG?format=json&date=2020:2023&per_page=10';
    
    $ch = curl_init();
    curl_setopt_array($ch, [
        CURLOPT_URL => $testUrl,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_TIMEOUT => 15,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);
    $totalTime = round(curl_getinfo($ch, CURLINFO_TOTAL_TIME), 2);
    curl_close($ch);
    
    if ($error) {
        $checks[] = ['❌', 'WB API Bağlantı', "cURL Hatası: $error"];
    } elseif ($httpCode !== 200) {
        $checks[] = ['❌', 'WB API HTTP', "HTTP $httpCode döndü (200 olmalı)"];
    } else {
        $decoded = json_decode($response, true);
        if (is_array($decoded) && count($decoded) >= 2 && is_array($decoded[1])) {
            $dataCount = count($decoded[1]);
            $sampleValue = $decoded[1][0]['value'] ?? 'null';
            $sampleDate = $decoded[1][0]['date'] ?? '?';
            $checks[] = ['✅', 'WB API Çalışıyor', 
                "HTTP 200, {$totalTime}s, $dataCount kayıt döndü. " .
                "Örnek: Türkiye Enflasyon ($sampleDate) = $sampleValue%"
            ];
        } else {
            $checks[] = ['⚠️', 'WB API Format', 'Yanıt beklenmeyen formatta: ' . substr($response, 0, 200)];
        }
    }
} catch (Exception $e) {
    $checks[] = ['❌', 'WB API Test', 'Exception: ' . $e->getMessage()];
}

// ─── 8. PHP endpoint testi ───
$endpoints = [
    'countries' => '?action=countries',
    'intl_indicators' => '?action=intl_indicators',
    'sustainability' => '?action=sustainability&countries=TUR,USA,DEU',
];

foreach ($endpoints as $name => $query) {
    try {
        // Doğrudan fonksiyon çağrısı yerine, self-request
        $selfUrl = (isset($_SERVER['HTTPS']) ? 'https' : 'http') . '://' . $_SERVER['HTTP_HOST'] . dirname($_SERVER['REQUEST_URI']) . '/api.php' . $query;
        
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $selfUrl,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 10,
        ]);
        $resp = curl_exec($ch);
        $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        
        if ($code === 200) {
            $json = json_decode($resp, true);
            if (isset($json['success']) && $json['success']) {
                $dataCount = 0;
                if (isset($json['data'])) {
                    $dataCount = is_array($json['data']) ? count($json['data']) : 0;
                }
                $icon = $dataCount > 0 ? '✅' : '⚠️';
                $checks[] = [$icon, "Endpoint: $name", "HTTP 200, success=true, $dataCount kayıt"];
            } elseif (isset($json['error'])) {
                $checks[] = ['❌', "Endpoint: $name", "Hata: {$json['error']}"];
            } else {
                $checks[] = ['⚠️', "Endpoint: $name", "HTTP 200 ama beklenmeyen yanıt: " . substr($resp, 0, 150)];
            }
        } else {
            $checks[] = ['❌', "Endpoint: $name", "HTTP $code: " . substr($resp, 0, 200)];
        }
    } catch (Exception $e) {
        $checks[] = ['❌', "Endpoint: $name", $e->getMessage()];
    }
}

// ─── 9. Tek gösterge fetch testi (opsiyonel) ───
if (isset($_GET['fetch_test'])) {
    try {
        require_once __DIR__ . '/services/WorldBankService.php';
        $wb = new WorldBankService();
        
        // İlk aktif göstergeyi bul
        $stmt = $db->query("SELECT id, source_code, name_tr FROM international_indicators WHERE is_active = 1 LIMIT 1");
        $testInd = $stmt->fetch();
        
        if ($testInd) {
            $checks[] = ['ℹ️', 'Fetch Test', "Gösterge #{$testInd['id']} ({$testInd['name_tr']}) için veri çekiliyor..."];
            $result = $wb->fetchIndicatorData($testInd['id'], ['TUR', 'USA', 'DEU'], 2020, 2024);
            $icon = $result['success'] ? '✅' : '❌';
            $checks[] = [$icon, 'Fetch Sonuç', json_encode($result, JSON_UNESCAPED_UNICODE)];
        } else {
            $checks[] = ['❌', 'Fetch Test', 'Test edilecek gösterge bulunamadı'];
        }
    } catch (Exception $e) {
        $checks[] = ['❌', 'Fetch Test', 'Exception: ' . $e->getMessage()];
    }
}

outputHtml($checks);

// ─── HTML Output ───
function outputHtml(array $checks): void {
    $fetchTestUrl = '?fetch_test=1';
    echo "<!DOCTYPE html><html><head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>Uluslararası Veri Tanılama</title>
    <style>
        * { margin:0; padding:0; box-sizing:border-box; }
        body { font-family: 'Segoe UI', system-ui, sans-serif; background:#0f0f23; color:#e0e0e0; padding:20px; }
        h1 { color:#4ecdc4; margin-bottom:20px; font-size:22px; }
        .check { padding:12px 16px; margin:6px 0; border-radius:8px; background:#1a1a2e; border:1px solid #2a2a4a; }
        .check-icon { font-size:18px; margin-right:10px; }
        .check-title { font-weight:600; color:#fff; margin-right:12px; }
        .check-detail { color:#aaa; font-size:13px; margin-top:4px; }
        .check-detail code { background:#16213e; padding:2px 6px; border-radius:4px; color:#4ecdc4; font-size:12px; }
        .actions { margin-top:20px; padding:16px; background:#16213e; border-radius:10px; border:1px solid #2a2a4a; }
        .actions h3 { color:#ffa726; margin-bottom:10px; }
        .actions pre { background:#0f0f23; padding:12px; border-radius:6px; font-size:12px; color:#4ecdc4; overflow-x:auto; white-space:pre-wrap; }
        a.btn { display:inline-block; padding:8px 16px; background:#4ecdc4; color:#000; border-radius:6px; text-decoration:none; font-weight:600; font-size:13px; margin-top:10px; }
        a.btn:hover { background:#45b7d1; }
        .summary { padding:16px; margin:16px 0; border-radius:10px; }
        .summary-ok { background:rgba(78,205,196,0.1); border:1px solid rgba(78,205,196,0.3); }
        .summary-bad { background:rgba(255,107,107,0.1); border:1px solid rgba(255,107,107,0.3); }
    </style></head><body>";
    
    echo "<h1>🔍 Uluslararası Veri Tanılama</h1>";
    
    $hasError = false;
    $hasDataPoints = false;
    foreach ($checks as $c) {
        if ($c[0] === '❌') $hasError = true;
        if (strpos($c[1], 'Uluslararası Veri') !== false && $c[0] === '✅') $hasDataPoints = true;
        
        echo "<div class='check'>";
        echo "<span class='check-icon'>{$c[0]}</span>";
        echo "<span class='check-title'>{$c[1]}</span>";
        echo "<div class='check-detail'>{$c[2]}</div>";
        echo "</div>";
    }
    
    if (!$hasDataPoints) {
        echo "<div class='summary summary-bad'>";
        echo "<h3 style='color:#ff6b6b; margin-bottom:8px;'>⚠️ Ana Sorun: Uluslararası veri yok</h3>";
        echo "<p style='font-size:13px; margin-bottom:12px;'>Ülke Kıyaslama ve Yeşil Göstergeler ekranlarının çalışması için <code>international_data_points</code> tablosuna veri gerekli.</p>";
        echo "<p style='font-size:13px;'><strong>Çözüm 1 (Hızlı):</strong> <code>seed_international_data.sql</code> dosyasını phpMyAdmin'den import edin.</p>";
        echo "<p style='font-size:13px; margin-top:4px;'><strong>Çözüm 2 (API):</strong> SSH'dan <code>php fetch_international.php --verbose</code> çalıştırın.</p>";
        echo "<p style='font-size:13px; margin-top:8px;'><a class='btn' href='{$fetchTestUrl}'>🧪 Tek Gösterge Fetch Testi Yap</a></p>";
        echo "</div>";
    } else {
        echo "<div class='summary summary-ok'>";
        echo "<h3 style='color:#4ecdc4;'>✅ Her şey çalışıyor!</h3>";
        echo "<p style='font-size:13px;'>Uluslararası veriler mevcut, API'ler çalışıyor.</p>";
        echo "</div>";
    }
    
    echo "</body></html>";
}