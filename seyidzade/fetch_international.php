<?php
/**
 * Cron Job - Uluslararası Veri Güncelleme
 * 
 * Dünya Bankası verilerini periyodik olarak çeker.
 * Yıllık veriler olduğu için haftada 1 kez çalıştırmak yeterlidir.
 * 
 * Crontab (her Pazartesi saat 10:00):
 * 0 10 * * 1 /usr/bin/php /path/to/fetch_international.php --verbose >> /var/log/intl-data.log 2>&1
 */

if (php_sapi_name() !== 'cli') {
    die('Bu script sadece CLI\'dan çalıştırılabilir.');
}

require_once __DIR__ . '/../services/WorldBankService.php';

$options = getopt('', ['verbose', 'indicator:', 'countries:']);
$verbose = isset($options['verbose']);
$specificId = isset($options['indicator']) ? (int) $options['indicator'] : null;
$countries = isset($options['countries'])
    ? array_map('trim', explode(',', $options['countries']))
    : [];

$startTime = microtime(true);
log_msg("=== Uluslararası veri güncelleme başlıyor ===", $verbose);
log_msg("Zaman: " . date('Y-m-d H:i:s'), $verbose);

try {
    $wb = new WorldBankService();

    if ($specificId) {
        log_msg("Gösterge #$specificId güncelleniyor...", $verbose);
        $result = $wb->fetchIndicatorData($specificId, $countries);
        log_msg("Sonuç: " . json_encode($result, JSON_UNESCAPED_UNICODE), $verbose);
    } else {
        log_msg("Tüm uluslararası göstergeler güncelleniyor...", $verbose);
        $results = $wb->fetchAllActive($countries);

        $successCount = 0;
        $errorCount = 0;

        foreach ($results as $id => $result) {
            if ($result['success']) {
                $successCount++;
                log_msg("  ✓ Gösterge #$id: {$result['message']}", $verbose);
            } else {
                $errorCount++;
                log_msg("  ✗ Gösterge #$id: {$result['message']}", true);
            }
        }

        log_msg("--- Özet ---", $verbose);
        log_msg("Başarılı: $successCount", $verbose);
        log_msg("Hatalı:   $errorCount", $verbose);
    }
} catch (Exception $e) {
    log_msg("FATAL ERROR: " . $e->getMessage(), true);
    exit(1);
}

$elapsed = round(microtime(true) - $startTime, 2);
log_msg("=== Tamamlandı ({$elapsed}s) ===", $verbose);

function log_msg(string $message, bool $verbose): void
{
    if ($verbose) echo date('[H:i:s] ') . $message . PHP_EOL;
    error_log(date('[Y-m-d H:i:s] ') . $message);
}
