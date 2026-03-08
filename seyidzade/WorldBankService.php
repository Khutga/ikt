<?php
/**
 * WorldBankService - Dünya Bankası API ile iletişim katmanı
 * 
 * Ülkeler arası kıyaslama verileri için Dünya Bankası Open Data API kullanır.
 * API Key gerektirmez, rate limit cömerttir.
 * 
 * API Dökümantasyon: https://datahelpdesk.worldbank.org/knowledgebase/articles/889392
 * 
 * Base URL: https://api.worldbank.org/v2/
 * Format: JSON (format=json)
 * Tarih: date=2015:2024 (yıl aralığı)
 * Çoklu ülke: country/TUR;USA;DEU
 */

require_once __DIR__ . '/../config/Database.php';

class WorldBankService
{
    private PDO $db;
    private string $baseUrl = 'https://api.worldbank.org/v2/';
    private int $timeout = 30;
    private int $perPage = 1000;

    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    // =========================================
    // ANA VERİ ÇEKME
    // =========================================

    /**
     * Tek bir gösterge için birden fazla ülkenin verisini çeker
     * 
     * @param int $intlIndicatorId  international_indicators tablosundaki ID
     * @param array $countryCodes   ISO3 kodları ['TUR','USA','DEU']
     * @param int $startYear        Başlangıç yılı
     * @param int $endYear          Bitiş yılı
     * @return array
     */
    public function fetchIndicatorData(
        int $intlIndicatorId,
        array $countryCodes = [],
        int $startYear = 2000,
        int $endYear = 0
    ): array {
        $startTime = microtime(true);

        if ($endYear === 0) {
            $endYear = (int) date('Y');
        }

        try {
            // 1. Gösterge bilgisini al
            $stmt = $this->db->prepare(
                "SELECT * FROM international_indicators WHERE id = ? AND is_active = 1"
            );
            $stmt->execute([$intlIndicatorId]);
            $indicator = $stmt->fetch();

            if (!$indicator) {
                return $this->logResult('worldbank', $indicator['source_code'] ?? '', 'error', 0, 0, 'Gösterge bulunamadı', $startTime);
            }

            // 2. Ülke kodlarını belirle (boşsa tüm aktif ülkeler)
            if (empty($countryCodes)) {
                $countryCodes = $this->getActiveCountryCodes();
            }

            // 3. API çağrısı
            $sourceCode = $indicator['source_code'];
            $countryParam = implode(';', $countryCodes);
            $rawData = $this->callApi(
                "country/{$countryParam}/indicator/{$sourceCode}",
                ['date' => "{$startYear}:{$endYear}"]
            );

            if ($rawData === null) {
                return $this->logResult('worldbank', $sourceCode, 'error', 0, 0, 'API yanıt vermedi', $startTime);
            }

            // 4. Veriyi parse et ve DB'ye yaz
            $result = $this->parseAndStore($intlIndicatorId, $rawData);

            // 5. Meta güncelle
            $this->updateIndicatorMeta($intlIndicatorId);

            return $this->logResult(
                'worldbank', $sourceCode, 'success',
                $result['fetched'], $result['inserted'],
                "Başarılı: {$result['inserted']} yeni kayıt ({$result['countries']} ülke)",
                $startTime
            );

        } catch (Exception $e) {
            error_log("WorldBank fetch error: " . $e->getMessage());
            return $this->logResult('worldbank', '', 'error', 0, 0, $e->getMessage(), $startTime);
        }
    }

    /**
     * Tüm aktif uluslararası göstergeleri günceller
     */
    public function fetchAllActive(array $countryCodes = []): array
    {
        $results = [];

        $stmt = $this->db->query(
            "SELECT id, source_code FROM international_indicators WHERE is_active = 1 AND source_type = 'worldbank' ORDER BY id"
        );
        $indicators = $stmt->fetchAll();

        foreach ($indicators as $ind) {
            // Rate limit: İstekler arası bekleme
            usleep(500000); // 0.5 saniye

            $results[$ind['id']] = $this->fetchIndicatorData($ind['id'], $countryCodes);
        }

        return $results;
    }

    // =========================================
    // VERİ SORGULAMA (Flutter API için)
    // =========================================

    /**
     * Ülke kıyaslama verisi döner
     * 
     * @param int $intlIndicatorId
     * @param array $countryCodes  ISO3 kodları
     * @param int $startYear
     * @param int $endYear
     * @return array
     */
    public function getComparisonData(
        int $intlIndicatorId,
        array $countryCodes,
        int $startYear = 2000,
        int $endYear = 0
    ): array {
        if ($endYear === 0) $endYear = (int) date('Y');

        // Gösterge bilgisi
        $stmt = $this->db->prepare("SELECT * FROM international_indicators WHERE id = ?");
        $stmt->execute([$intlIndicatorId]);
        $indicator = $stmt->fetch();

        if (!$indicator) return ['error' => 'Gösterge bulunamadı'];

        // Ülke ID'lerini bul
        $placeholders = str_repeat('?,', count($countryCodes) - 1) . '?';
        $stmt = $this->db->prepare(
            "SELECT id, iso_code, name_tr, flag_emoji FROM countries WHERE iso_code IN ($placeholders) AND is_active = 1"
        );
        $stmt->execute($countryCodes);
        $countries = $stmt->fetchAll();

        $countryMap = [];
        foreach ($countries as $c) {
            $countryMap[$c['id']] = $c;
        }

        // Her ülke için veri çek
        $series = [];
        foreach ($countries as $country) {
            $stmt = $this->db->prepare("
                SELECT idp.date, idp.value
                FROM international_data_points idp
                WHERE idp.intl_indicator_id = ?
                  AND idp.country_id = ?
                  AND YEAR(idp.date) BETWEEN ? AND ?
                ORDER BY idp.date ASC
            ");
            $stmt->execute([$intlIndicatorId, $country['id'], $startYear, $endYear]);

            $series[] = [
                'country' => [
                    'iso_code' => $country['iso_code'],
                    'name_tr' => $country['name_tr'],
                    'flag_emoji' => $country['flag_emoji'],
                ],
                'data' => $stmt->fetchAll(),
            ];
        }

        return [
            'success' => true,
            'indicator' => [
                'id' => $indicator['id'],
                'name_tr' => $indicator['name_tr'],
                'name_en' => $indicator['name_en'],
                'unit' => $indicator['unit'],
                'source_type' => $indicator['source_type'],
            ],
            'period' => ['start' => $startYear, 'end' => $endYear],
            'series' => $series,
        ];
    }

    /**
     * Tüm uluslararası göstergeleri listele
     */
    public function getIndicators(?string $categoryCode = null): array
    {
        $sql = "
            SELECT ii.*, c.name_tr as category_name_tr, c.code as category_code
            FROM international_indicators ii
            JOIN categories c ON c.id = ii.category_id
            WHERE ii.is_active = 1
        ";
        $params = [];

        if ($categoryCode) {
            $sql .= " AND c.code = ?";
            $params[] = $categoryCode;
        }

        $sql .= " ORDER BY c.sort_order, ii.id";

        $stmt = $this->db->prepare($sql);
        $stmt->execute($params);

        return $stmt->fetchAll();
    }

    /**
     * Aktif ülkeleri listele
     */
    public function getCountries(): array
    {
        $stmt = $this->db->query(
            "SELECT * FROM countries WHERE is_active = 1 ORDER BY sort_order"
        );
        return $stmt->fetchAll();
    }

    // =========================================
    // API İLETİŞİM
    // =========================================

    private function callApi(string $endpoint, array $params = []): ?array
    {
        $params['format'] = 'json';
        $params['per_page'] = $this->perPage;

        $url = $this->baseUrl . $endpoint . '?' . http_build_query($params);

        $ch = curl_init();
        curl_setopt_array($ch, [
            CURLOPT_URL => $url,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => $this->timeout,
            CURLOPT_FOLLOWLOCATION => true,
            CURLOPT_SSL_VERIFYPEER => true,
            CURLOPT_HTTPHEADER => ['Accept: application/json'],
        ]);

        $response = curl_exec($ch);
        $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
        $error = curl_error($ch);
        curl_close($ch);

        if ($error) {
            error_log("WorldBank cURL error: $error");
            return null;
        }

        if ($httpCode !== 200) {
            error_log("WorldBank API HTTP $httpCode: $response");
            return null;
        }

        $decoded = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) {
            error_log("WorldBank JSON parse error: " . json_last_error_msg());
            return null;
        }

        // Dünya Bankası API [metadata, data] formatında döner
        if (is_array($decoded) && count($decoded) >= 2) {
            return $decoded[1] ?? [];
        }

        return $decoded;
    }

    // =========================================
    // VERİ İŞLEME
    // =========================================

    /**
     * Dünya Bankası API yanıtını parse edip DB'ye yazar
     * 
     * WB API format:
     * [
     *   { "country": {"id": "TR", "value": "Turkiye"},
     *     "date": "2023", "value": 53.86, "indicator": {...} },
     *   ...
     * ]
     */
    private function parseAndStore(int $intlIndicatorId, array $rawData): array
    {
        $fetched = count($rawData);
        $inserted = 0;
        $countriesSeen = [];

        if (empty($rawData)) {
            return ['fetched' => 0, 'inserted' => 0, 'countries' => 0];
        }

        $stmt = $this->db->prepare(
            "INSERT INTO international_data_points (intl_indicator_id, country_id, date, value)
             VALUES (:ind_id, :country_id, :date, :value)
             ON DUPLICATE KEY UPDATE value = VALUES(value)"
        );

        $this->db->beginTransaction();

        try {
            foreach ($rawData as $item) {
                $countryIso2 = $item['countryiso3code'] ?? ($item['country']['id'] ?? null);
                $value = $item['value'] ?? null;
                $dateStr = $item['date'] ?? null;

                if ($countryIso2 === null || $value === null || $dateStr === null) continue;
                if (!is_numeric($value)) continue;

                // Ülke ID'sini bul (ISO3 veya ISO2)
                $countryId = $this->findCountryId($countryIso2);
                if (!$countryId) continue;

                // Yıl → tarih formatı
                $date = strlen($dateStr) === 4 ? "{$dateStr}-01-01" : $dateStr;

                $stmt->execute([
                    ':ind_id' => $intlIndicatorId,
                    ':country_id' => $countryId,
                    ':date' => $date,
                    ':value' => (float) $value,
                ]);

                if ($stmt->rowCount() > 0) $inserted++;
                $countriesSeen[$countryIso2] = true;
            }

            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }

        return [
            'fetched' => $fetched,
            'inserted' => $inserted,
            'countries' => count($countriesSeen),
        ];
    }

    private function findCountryId(string $code): ?int
    {
        // Önce ISO3 ile dene
        $stmt = $this->db->prepare(
            "SELECT id FROM countries WHERE iso_code = ? OR iso2 = ? LIMIT 1"
        );
        $stmt->execute([$code, $code]);
        $row = $stmt->fetch();
        return $row ? (int) $row['id'] : null;
    }

    private function getActiveCountryCodes(): array
    {
        $stmt = $this->db->query("SELECT iso_code FROM countries WHERE is_active = 1");
        return array_column($stmt->fetchAll(), 'iso_code');
    }

    private function updateIndicatorMeta(int $intlIndicatorId): void
    {
        $this->db->prepare("
            UPDATE international_indicators SET last_fetched_at = NOW() WHERE id = ?
        ")->execute([$intlIndicatorId]);
    }

    private function logResult(
        string $sourceType,
        string $indicatorCode,
        string $status,
        int $fetched,
        int $inserted,
        string $message,
        float $startTime
    ): array {
        $executionMs = (int) ((microtime(true) - $startTime) * 1000);

        try {
            $stmt = $this->db->prepare("
                INSERT INTO external_fetch_logs (source_type, indicator_code, status, records_fetched, records_inserted, error_message, execution_time_ms)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([
                $sourceType, $indicatorCode, $status,
                $fetched, $inserted,
                $status === 'error' ? $message : null,
                $executionMs,
            ]);
        } catch (Exception $e) {
            error_log("Log write error: " . $e->getMessage());
        }

        return [
            'success' => $status === 'success',
            'fetched' => $fetched,
            'inserted' => $inserted,
            'message' => $message,
            'time_ms' => $executionMs,
        ];
    }
}
