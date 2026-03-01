<?php
/**
 * Makroekonomik Dashboard - Yapılandırma Dosyası
 * 
 * Bu dosyayı config.local.php olarak kopyalayıp
 * kendi değerlerinizi girin. config.local.php .gitignore'dadır.
 */

return [
    // Veritabanı Ayarları
    'db' => [
        'host'     => getenv('DB_HOST') ?: 'localhost',
        'port'     => getenv('DB_PORT') ?: 3306,
        'name'     => getenv('DB_NAME') ?: 'macro_dashboard',
        'user'     => getenv('DB_USER') ?: 'root',
        'password' => getenv('DB_PASS') ?: '',
        'charset'  => 'utf8mb4',
    ],

    // TCMB EVDS API Ayarları
    'evds' => [
        'base_url' => 'https://evds2.tcmb.gov.tr/service/evds/',
        'api_key'  => getenv('EVDS_API_KEY') ?: 'BURAYA_API_KEYINIZI_GIRIN',
        // Rate limit: Günde en fazla kaç istek atılsın
        'daily_request_limit' => 500,
        // İstek arası bekleme süresi (saniye)
        'request_delay' => 1,
    ],

    // Python Mikroservis Ayarları
    'python_service' => [
        'base_url' => getenv('PYTHON_SERVICE_URL') ?: 'http://localhost:8001',
        'timeout'  => 30, // saniye
    ],

    // Uygulama Ayarları
    'app' => [
        'name'       => 'Makroekonomik Dashboard',
        'version'    => '1.0.0',
        'debug'      => getenv('APP_DEBUG') ?: false,
        'timezone'   => 'Europe/Istanbul',
        'locale'     => 'tr',
        // Veri çekme varsayılan tarih aralığı (yıl)
        'default_history_years' => 10,
    ],

    // CORS Ayarları (Flutter'dan erişim için)
    'cors' => [
        'allowed_origins' => ['*'],
        'allowed_methods' => ['GET', 'POST', 'OPTIONS'],
        'allowed_headers' => ['Content-Type', 'Authorization', 'X-Requested-With'],
    ],

    // Cache Ayarları
    'cache' => [
        // Analiz sonuçları cache süresi (saniye)
        'analysis_ttl' => 3600, // 1 saat
        // API yanıt cache süresi (saniye)
        'api_response_ttl' => 300, // 5 dakika
    ],
];