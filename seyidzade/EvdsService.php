<?php
/**
 * EvdsService - TCMB EVDS API ile iletişim katmanı
 * 
 * Bu servis EVDS API'sine bağlanarak ekonomik verileri çeker.
 * 
 * EVDS API Özet:
 * - Base URL: https://evds2.tcmb.gov.tr/service/evds/
 * - API key HTTP header olarak gönderilir ("key" header'ı)
 * - Tarih formatı: dd-mm-yyyy
 * - Frekanslar: 1=günlük, 2=işgünü, 3=haftalık, 5=aylık, 6=3aylık, 8=yıllık
 * - Formüller: 0=düzey, 1=yüzde değişim, 3=yıllık yüzde değişim
 */

require_once __DIR__ . '/../config/Database.php';

class EvdsService
{
    private PDO $db;
    private array $config;
    private string $baseUrl;
    private string $apiKey;

    public function __construct()
    {
        $this->db = Database::getConnection();
        $this->config = require __DIR__ . '/../config/config.php';
        $this->baseUrl = $this->config['evds']['base_url'];
        $this->apiKey = $this->config['evds']['api_key'];
    }

    // =========================================
    // ANA VERİ ÇEKME FONKSİYONLARI
    // =========================================

    /**
     * Tek bir gösterge için EVDS'den veri çeker ve DB'ye yazar
     * 
     * @param int $indicatorId  Gösterge ID'si
     * @param string|null $startDate  Başlangıç (dd-mm-yyyy), null ise son veri tarihinden devam
     * @param string|null $endDate    Bitiş (dd-mm-yyyy), null ise bugün
     * @return array ['success' => bool, 'inserted' => int, 'message' => string]
     */
    public function fetchIndicatorData(int $indicatorId, ?string $startDate = null, ?string $endDate = null): array
    {
        $startTime = microtime(true);

        try {
            // 1. Gösterge bilgilerini al
            $indicator = $this->getIndicatorById($indicatorId);
            if (!$indicator) {
                return $this->logAndReturn($indicatorId, 'error', 0, 0, 'Gösterge bulunamadı', $startTime);
            }

            // 2. Tarih aralığını belirle
            if ($startDate === null) {
                $startDate = $this->getSmartStartDate($indicator);
            }
            if ($endDate === null) {
                $endDate = date('d-m-Y');
            }

            // 3. EVDS API çağrısı
            $evdsCode = $indicator['evds_code'];
            $rawData = $this->callEvdsApi($evdsCode, $startDate, $endDate);

            if ($rawData === null) {
                return $this->logAndReturn($indicatorId, 'error', 0, 0, 'EVDS API yanıt vermedi', $startTime);
            }

            // 4. Veriyi parse et ve DB'ye yaz
            $result = $this->parseAndStore($indicatorId, $evdsCode, $rawData);

            // 5. Gösterge meta bilgisini güncelle
            $this->updateIndicatorMeta($indicatorId);

            return $this->logAndReturn(
                $indicatorId,
                'success',
                $result['fetched'],
                $result['inserted'],
                "Başarılı: {$result['inserted']} yeni kayıt",
                $startTime
            );

        } catch (Exception $e) {
            error_log("EVDS fetch error (indicator: $indicatorId): " . $e->getMessage());
            return $this->logAndReturn($indicatorId, 'error', 0, 0, $e->getMessage(), $startTime);
        }
    }

    /**
     * Tüm aktif göstergelerin verilerini günceller
     * Cron job tarafından çağrılır
     * 
     * @return array Her gösterge için sonuç
     */
    public function fetchAllActive(): array
    {
        $results = [];

        $stmt = $this->db->query(
            "SELECT id, evds_code, frequency FROM indicators WHERE is_active = 1 ORDER BY id"
        );
        $indicators = $stmt->fetchAll();

        foreach ($indicators as $indicator) {
            // Frekansa göre güncelleme gerekli mi kontrol et
            if (!$this->needsUpdate($indicator)) {
                $results[$indicator['id']] = [
                    'success' => true,
                    'skipped' => true,
                    'message' => 'Güncelleme gerekmiyor'
                ];
                continue;
            }

            // Rate limit: İstekler arası bekleme
            usleep($this->config['evds']['request_delay'] * 1000000);

            $results[$indicator['id']] = $this->fetchIndicatorData($indicator['id']);
        }

        return $results;
    }

    /**
     * Birden fazla göstergeyi tek API çağrısında çeker
     * EVDS API aynı anda birden fazla seriyi destekler (seri kodları "-" ile ayrılır)
     * 
     * @param array $indicatorIds
     * @param string $startDate
     * @param string $endDate
     * @return array
     */
    public function fetchMultiple(array $indicatorIds, string $startDate, string $endDate): array
    {
        // Gösterge kodlarını topla
        $placeholders = str_repeat('?,', count($indicatorIds) - 1) . '?';
        $stmt = $this->db->prepare(
            "SELECT id, evds_code FROM indicators WHERE id IN ($placeholders) AND is_active = 1"
        );
        $stmt->execute($indicatorIds);
        $indicators = $stmt->fetchAll();

        if (empty($indicators)) {
            return ['success' => false, 'message' => 'Gösterge bulunamadı'];
        }

        // EVDS çoklu seri desteği: kodlar "-" ile ayrılır
        $codes = array_column($indicators, 'evds_code');
        $seriesParam = implode('-', $codes);

        $rawData = $this->callEvdsApi($seriesParam, $startDate, $endDate);
        if ($rawData === null) {
            return ['success' => false, 'message' => 'EVDS API yanıt vermedi'];
        }

        // Her gösterge için ayrı ayrı parse et
        $totalInserted = 0;
        foreach ($indicators as $ind) {
            $result = $this->parseAndStore($ind['id'], $ind['evds_code'], $rawData);
            $totalInserted += $result['inserted'];
        }

        return [
            'success' => true,
            'total_inserted' => $totalInserted,
            'indicators_count' => count($indicators)
        ];
    }

    // =========================================
    // EVDS API İLETİŞİM
    // =========================================

    /**
     * EVDS API'sine HTTP isteği gönderir
     * 
     * @param string $seriesCodes  Seri kodları ("-" ile ayrılmış)
     * @param string $startDate    dd-mm-yyyy
     * @param string $endDate      dd-mm-yyyy
     * @param string $type         json|xml|csv
     * @return array|null          API yanıtı (decode edilmiş)
     */
    private function callEvdsApi(
        string $seriesCodes,
        string $startDate,
        string $endDate,
        string $type = 'json'
    ): ?array {
        // EVDS3 URL formatı: base_url + series=X&startDate=Y&endDate=Z&type=json
        // Not: EVDS3 standart query string (?) kullanmaz, parametreler / sonrası direkt eklenir
        $url = $this->baseUrl
            . 'series=' . $seriesCodes
            . '&startDate=' . $startDate
            . '&endDate=' . $endDate
            . '&type=' . $type;

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 30,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_HTTPHEADER     => [
                'key: ' . $this->apiKey,
                'Accept: application/json',
            ],
            // Shared hosting'lerde EVDS SSL sertifikası sorun çıkarabilir
            CURLOPT_SSL_VERIFYPEER => false,
            CURLOPT_SSL_VERIFYHOST => 0,
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($error) {
            error_log("EVDS cURL error: $error");
            return null;
        }

        if ($httpCode !== 200) {
            error_log("EVDS API HTTP $httpCode: $response");
            return null;
        }

        $decoded = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("EVDS JSON parse error: " . json_last_error_msg());
            return null;
        }

        return $decoded;
    }

    /**
     * EVDS metadata: Kategori listesini çeker
     */
    public function fetchCategories(): ?array
    {
        $url = $this->baseUrl . 'categories/type=json';
        return $this->callMetadataApi($url);
    }

    /**
     * EVDS metadata: Bir kategorideki veri gruplarını çeker
     */
    public function fetchDataGroups(int $categoryCode): ?array
    {
        $url = $this->baseUrl . "datagroups/mode=2&code=$categoryCode&type=json";
        return $this->callMetadataApi($url);
    }

    /**
     * EVDS metadata: Bir veri grubundaki seri listesini çeker
     */
    public function fetchSeriesList(string $dataGroupCode): ?array
    {
        $url = $this->baseUrl . "serieList/type=json&code=$dataGroupCode";
        return $this->callMetadataApi($url);
    }

    private function callMetadataApi(string $url): ?array
    {
        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL            => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT        => 15,
            CURLOPT_HTTPHEADER     => ['key: ' . $this->apiKey],
        ]);

        $response = curl_exec($ch);
        curl_close($ch);

        return $response ? json_decode($response, true) : null;
    }

    // =========================================
    // VERİ İŞLEME
    // =========================================

    /**
     * EVDS API yanıtını parse eder ve veritabanına yazar
     * 
     * EVDS JSON formatı:
     * {
     *   "items": [
     *     {"Tarih": "02-01-2024", "TP_DK_USD_A_YTL": "29.4350", ...},
     *     ...
     *   ]
     * }
     * 
     * Not: JSON key'lerde "." yerine "_" kullanılır
     */
    private function parseAndStore(int $indicatorId, string $evdsCode, array $rawData): array
    {
        $items = $rawData['items'] ?? [];
        $fetched = count($items);
        $inserted = 0;

        if (empty($items)) {
            return ['fetched' => 0, 'inserted' => 0];
        }

        // EVDS seri kodundaki "." → "_" dönüşümü (JSON key formatı)
        $jsonKey = str_replace('.', '_', $evdsCode);

        $stmt = $this->db->prepare(
            "INSERT INTO data_points (indicator_id, date, value) 
             VALUES (:indicator_id, :date, :value)
             ON DUPLICATE KEY UPDATE value = VALUES(value)"
        );

        $this->db->beginTransaction();

        try {
            foreach ($items as $item) {
                $dateStr = $item['Tarih'] ?? null;
                $valueStr = $item[$jsonKey] ?? null;

                // Boş veya null değerleri atla
                if ($dateStr === null || $valueStr === null || $valueStr === '') {
                    continue;
                }

                // EVDS tarih formatı: dd-mm-yyyy → MySQL: yyyy-mm-dd
                $date = $this->evdsDateToMysql($dateStr);
                if ($date === null) continue;

                // Değeri float'a çevir (Türkçe ondalık ayırıcı virgül olabilir)
                $value = str_replace(',', '.', $valueStr);
                if (!is_numeric($value)) continue;

                $stmt->execute([
                    ':indicator_id' => $indicatorId,
                    ':date'         => $date,
                    ':value'        => (float) $value,
                ]);

                if ($stmt->rowCount() > 0) {
                    $inserted++;
                }
            }

            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }

        return ['fetched' => $fetched, 'inserted' => $inserted];
    }

    /**
     * EVDS tarih formatını MySQL'e çevirir
     * dd-mm-yyyy → yyyy-mm-dd
     */
    private function evdsDateToMysql(string $evdsDate): ?string
    {
        $parts = explode('-', $evdsDate);
        if (count($parts) !== 3) return null;

        return sprintf('%s-%s-%s', $parts[2], $parts[1], $parts[0]);
    }

    // =========================================
    // YARDIMCI FONKSİYONLAR
    // =========================================

    /**
     * Akıllı başlangıç tarihi: Son veriden devam eder
     * İlk çekimde ise default_history_years kadar geriye gider
     */
    private function getSmartStartDate(array $indicator): string
    {
        // Son veri tarihini kontrol et
        $stmt = $this->db->prepare(
            "SELECT MAX(date) as last_date FROM data_points WHERE indicator_id = ?"
        );
        $stmt->execute([$indicator['id']]);
        $row = $stmt->fetch();

        if ($row && $row['last_date']) {
            // Son veriden 1 gün sonrasından devam et (overlap için aynı gün de olabilir)
            $lastDate = new DateTime($row['last_date']);
            return $lastDate->format('d-m-Y');
        }

        // İlk çekim: N yıl geriye git
        $years = $this->config['app']['default_history_years'];
        $startDate = new DateTime("-{$years} years");
        return $startDate->format('d-m-Y');
    }

    /**
     * Frekansa göre güncelleme gerekli mi kontrol eder
     * Günlük veri: her gün / Aylık veri: ayda bir / vs.
     */
    private function needsUpdate(array $indicator): bool
    {
        if (!$indicator['last_fetched_at'] ?? true) {
            return true; // Hiç çekilmemişse kesinlikle güncelle
        }

        // NOT: DB'den gelen indicator'da last_fetched_at yok,
        // bu bilgi indicators tablosundan ayrı sorgulanmalı
        $stmt = $this->db->prepare(
            "SELECT last_fetched_at FROM indicators WHERE id = ?"
        );
        $stmt->execute([$indicator['id']]);
        $row = $stmt->fetch();

        if (!$row || !$row['last_fetched_at']) return true;

        $lastFetched = new DateTime($row['last_fetched_at']);
        $now = new DateTime();
        $diff = $now->diff($lastFetched);

        return match ($indicator['frequency']) {
            'daily'     => $diff->days >= 1 || $diff->h >= 6,
            'weekly'    => $diff->days >= 1,
            'monthly'   => $diff->days >= 1,
            'quarterly' => $diff->days >= 7,
            'yearly'    => $diff->days >= 30,
            default     => true,
        };
    }

    /**
     * Göstergenin meta bilgilerini günceller (son değer, son çekme zamanı)
     */
    private function updateIndicatorMeta(int $indicatorId): void
    {
        $stmt = $this->db->prepare("
            UPDATE indicators i
            SET 
                last_fetched_at = NOW(),
                last_value = (
                    SELECT value FROM data_points 
                    WHERE indicator_id = ? 
                    ORDER BY date DESC LIMIT 1
                ),
                last_value_date = (
                    SELECT date FROM data_points 
                    WHERE indicator_id = ? 
                    ORDER BY date DESC LIMIT 1
                )
            WHERE i.id = ?
        ");
        $stmt->execute([$indicatorId, $indicatorId, $indicatorId]);
    }

    private function getIndicatorById(int $id): ?array
    {
        $stmt = $this->db->prepare("SELECT * FROM indicators WHERE id = ?");
        $stmt->execute([$id]);
        return $stmt->fetch() ?: null;
    }

    /**
     * Loglama + sonuç döndürme (DRY)
     */
    private function logAndReturn(
        int $indicatorId,
        string $status,
        int $fetched,
        int $inserted,
        string $message,
        float $startTime
    ): array {
        $executionMs = (int) ((microtime(true) - $startTime) * 1000);

        // fetch_logs tablosuna yaz
        $stmt = $this->db->prepare("
            INSERT INTO fetch_logs (indicator_id, fetch_type, status, records_fetched, records_inserted, error_message, execution_time_ms)
            VALUES (?, 'single', ?, ?, ?, ?, ?)
        ");
        $stmt->execute([
            $indicatorId,
            $status,
            $fetched,
            $inserted,
            $status === 'error' ? $message : null,
            $executionMs,
        ]);

        return [
            'success'  => $status === 'success',
            'fetched'  => $fetched,
            'inserted' => $inserted,
            'message'  => $message,
            'time_ms'  => $executionMs,
        ];
    }
}