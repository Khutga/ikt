<?php
/**
 * Cron Job - Otomatik Veri Güncelleme
 * 
 * Bu script crontab ile çalıştırılır.
 * Tüm aktif göstergelerin verilerini EVDS'den çeker.
 * 
 * Crontab örneği (her gün saat 09:00'da):
 * 0 9 * * * /usr/bin/php /path/to/macro-dashboard/backend-php/cron/fetch_data.php >> /var/log/macro-dashboard.log 2>&1
 * 
 * Hafta içi günlük veri çekme (döviz kurları vb):
 * 0 18 * * 1-5 /usr/bin/php /path/to/macro-dashboard/backend-php/cron/fetch_data.php --frequency=daily
 * 
 * Aylık veri çekme (enflasyon, işsizlik vb):
 * 0 10 5 * * /usr/bin/php /path/to/macro-dashboard/backend-php/cron/fetch_data.php --frequency=monthly
 */

// CLI'den çalıştırıldığından emin ol
if (php_sapi_name() !== 'cli') {
    die('Bu script sadece CLI\'dan çalıştırılabilir.');
}

require_once __DIR__ . '/../services/EvdsService.php';

// Argüman parsing
$options = getopt('', ['frequency:', 'id:', 'verbose', 'dry-run']);
$frequency = $options['frequency'] ?? null;
$specificId = isset($options['id']) ? (int) $options['id'] : null;
$verbose = isset($options['verbose']);
$dryRun = isset($options['dry-run']);

$startTime = microtime(true);
log_msg("=== Veri güncelleme başlıyor ===", $verbose);
log_msg("Zaman: " . date('Y-m-d H:i:s'), $verbose);

try {
    $evds = new EvdsService();

    if ($specificId) {
        // Tek gösterge güncelle
        log_msg("Gösterge #$specificId güncelleniyor...", $verbose);
        if (!$dryRun) {
            $result = $evds->fetchIndicatorData($specificId);
            log_msg("Sonuç: " . json_encode($result, JSON_UNESCAPED_UNICODE), $verbose);
        }
    } else {
        // Tüm aktif göstergeleri güncelle
        log_msg("Tüm aktif göstergeler güncelleniyor...", $verbose);

        if ($frequency) {
            log_msg("Frekans filtresi: $frequency", $verbose);
        }

        if (!$dryRun) {
            $results = $evds->fetchAllActive();

            $successCount = 0;
            $errorCount = 0;
            $skippedCount = 0;

            foreach ($results as $id => $result) {
                if ($result['skipped'] ?? false) {
                    $skippedCount++;
                    continue;
                }
                if ($result['success']) {
                    $successCount++;
                    log_msg("  ✓ Gösterge #$id: {$result['message']}", $verbose);
                } else {
                    $errorCount++;
                    log_msg("  ✗ Gösterge #$id: {$result['message']}", true); // Hataları her zaman logla
                }
            }

            log_msg("--- Özet ---", $verbose);
            log_msg("Başarılı: $successCount", $verbose);
            log_msg("Atlanan:  $skippedCount", $verbose);
            log_msg("Hatalı:   $errorCount", $verbose);
        } else {
            log_msg("[DRY RUN] Veri çekilmedi, sadece simülasyon.", $verbose);
        }
    }

} catch (Exception $e) {
    log_msg("FATAL ERROR: " . $e->getMessage(), true);
    exit(1);
}

$elapsed = round(microtime(true) - $startTime, 2);
log_msg("=== Tamamlandı ({$elapsed}s) ===", $verbose);

// Cache temizliği (süresi geçmiş analiz cache'leri sil)
try {
    $db = Database::getConnection();
    $deleted = $db->exec("DELETE FROM analysis_cache WHERE expires_at < NOW()");
    if ($deleted > 0) {
        log_msg("$deleted süresi geçmiş cache kaydı silindi.", $verbose);
    }
} catch (Exception $e) {
    log_msg("Cache temizlik hatası: " . $e->getMessage(), $verbose);
}

// =========================================

function log_msg(string $message, bool $verbose): void
{
    if ($verbose) {
        echo date('[H:i:s] ') . $message . PHP_EOL;
    }
    // Dosyaya da yaz (cron çıktısı için)
    error_log(date('[Y-m-d H:i:s] ') . $message);
}