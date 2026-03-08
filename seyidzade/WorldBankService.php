<?php
/**
 * WorldBankService - Dünya Bankası API ile iletişim katmanı (v2 - BUG FIX)
 * 
 * Düzeltmeler:
 * 1. fetchIndicatorData(): null indicator erişim hatası ($indicator['source_code'] crash) 
 * 2. parseAndStore(): countryiso3code doğru okunuyor
 * 3. findCountryId(): performans için cache eklendi
 * 4. Tüm fonksiyonlarda error handling güçlendirildi
 */

require_once __DIR__ . '/../config/Database.php';

class WorldBankService
{
    private PDO $db;
    private string $baseUrl = 'https://api.worldbank.org/v2/';
    private int $timeout = 30;
    private int $perPage = 1000;
    private array $countryIdCache = [];

    public function __construct()
    {
        $this->db = Database::getConnection();
    }

    // =========================================
    // ANA VERİ ÇEKME
    // =========================================

    public function fetchIndicatorData(
        int $intlIndicatorId,
        array $countryCodes = [],
        int $startYear = 2000,
        int $endYear = 0
    ): array {
        $startTime = microtime(true);
        if ($endYear === 0) $endYear = (int) date('Y');

        try {
            $stmt = $this->db->prepare(
                "SELECT * FROM international_indicators WHERE id = ? AND is_active = 1"
            );
            $stmt->execute([$intlIndicatorId]);
            $indicator = $stmt->fetch();

            // ★ FIX: null check BEFORE accessing properties
            if (!$indicator) {
                return $this->logResult('worldbank', "id:$intlIndicatorId", 'error', 0, 0, 'Gösterge bulunamadı', $startTime);
            }

            $sourceCode = $indicator['source_code'];

            if (empty($countryCodes)) {
                $countryCodes = $this->getActiveCountryCodes();
            }
            if (empty($countryCodes)) {
                return $this->logResult('worldbank', $sourceCode, 'error', 0, 0, 'Aktif ülke bulunamadı', $startTime);
            }

            $countryParam = implode(';', $countryCodes);
            $rawData = $this->callApi(
                "country/{$countryParam}/indicator/{$sourceCode}",
                ['date' => "{$startYear}:{$endYear}"]
            );

            if ($rawData === null || empty($rawData)) {
                return $this->logResult('worldbank', $sourceCode, 'error', 0, 0, 'API boş yanıt döndü', $startTime);
            }

            $result = $this->parseAndStore($intlIndicatorId, $rawData);
            $this->updateIndicatorMeta($intlIndicatorId);

            return $this->logResult(
                'worldbank', $sourceCode, 'success',
                $result['fetched'], $result['inserted'],
                "Başarılı: {$result['inserted']} kayıt ({$result['countries']} ülke)",
                $startTime
            );
        } catch (Exception $e) {
            error_log("WorldBank fetch error (id:$intlIndicatorId): " . $e->getMessage());
            return $this->logResult('worldbank', '', 'error', 0, 0, $e->getMessage(), $startTime);
        }
    }

    public function fetchAllActive(array $countryCodes = []): array
    {
        $results = [];
        $stmt = $this->db->query(
            "SELECT id, source_code FROM international_indicators WHERE is_active = 1 AND source_type = 'worldbank' ORDER BY id"
        );
        $indicators = $stmt->fetchAll();

        foreach ($indicators as $ind) {
            usleep(500000);
            $results[$ind['id']] = $this->fetchIndicatorData($ind['id'], $countryCodes);
        }
        return $results;
    }

    // =========================================
    // VERİ SORGULAMA (Flutter API için)
    // =========================================

    public function getComparisonData(
        int $intlIndicatorId,
        array $countryCodes,
        int $startYear = 2000,
        int $endYear = 0
    ): array {
        if ($endYear === 0) $endYear = (int) date('Y');

        $stmt = $this->db->prepare("SELECT * FROM international_indicators WHERE id = ?");
        $stmt->execute([$intlIndicatorId]);
        $indicator = $stmt->fetch();
        if (!$indicator) return ['error' => 'Gösterge bulunamadı'];

        if (empty($countryCodes)) return ['error' => 'Ülke kodu gerekli'];

        $placeholders = str_repeat('?,', count($countryCodes) - 1) . '?';
        $stmt = $this->db->prepare(
            "SELECT id, iso_code, name_tr, flag_emoji FROM countries WHERE iso_code IN ($placeholders) AND is_active = 1"
        );
        $stmt->execute($countryCodes);
        $countries = $stmt->fetchAll();

        if (empty($countries)) return ['error' => 'Seçilen ülkeler bulunamadı'];

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
                'decimal_places' => $indicator['decimal_places'] ?? 2,
            ],
            'period' => ['start' => $startYear, 'end' => $endYear],
            'series' => $series,
        ];
    }

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

    public function getCountries(): array
    {
        $stmt = $this->db->query("SELECT * FROM countries WHERE is_active = 1 ORDER BY sort_order");
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

        if ($error) { error_log("WorldBank cURL: $error"); return null; }
        if ($httpCode !== 200) { error_log("WorldBank HTTP $httpCode"); return null; }

        $decoded = json_decode($response, true);
        if (json_last_error() !== JSON_ERROR_NONE) return null;

        // WB format: [metadata, data]
        if (is_array($decoded) && count($decoded) >= 2 && is_array($decoded[1])) {
            return $decoded[1];
        }
        return is_array($decoded) ? $decoded : null;
    }

    // =========================================
    // VERİ İŞLEME
    // =========================================

    private function parseAndStore(int $intlIndicatorId, array $rawData): array
    {
        $fetched = count($rawData);
        $inserted = 0;
        $countriesSeen = [];
        if (empty($rawData)) return ['fetched' => 0, 'inserted' => 0, 'countries' => 0];

        $stmt = $this->db->prepare(
            "INSERT INTO international_data_points (intl_indicator_id, country_id, date, value)
             VALUES (:ind_id, :country_id, :date, :value)
             ON DUPLICATE KEY UPDATE value = VALUES(value)"
        );

        $this->db->beginTransaction();
        try {
            foreach ($rawData as $item) {
                // ★ FIX: WB API returns countryiso3code field
                $countryCode = $item['countryiso3code'] ?? $item['country']['id'] ?? null;
                $value = $item['value'] ?? null;
                $dateStr = $item['date'] ?? null;

                if (!$countryCode || $value === null || $dateStr === null) continue;
                if (!is_numeric($value)) continue;

                $countryId = $this->findCountryId($countryCode);
                if (!$countryId) continue;

                $date = strlen($dateStr) === 4 ? "{$dateStr}-01-01" : $dateStr;

                $stmt->execute([
                    ':ind_id' => $intlIndicatorId,
                    ':country_id' => $countryId,
                    ':date' => $date,
                    ':value' => (float) $value,
                ]);
                if ($stmt->rowCount() > 0) $inserted++;
                $countriesSeen[$countryCode] = true;
            }
            $this->db->commit();
        } catch (Exception $e) {
            $this->db->rollBack();
            throw $e;
        }

        return ['fetched' => $fetched, 'inserted' => $inserted, 'countries' => count($countriesSeen)];
    }

    // ★ FIX: Cache eklendi
    private function findCountryId(string $code): ?int
    {
        if (isset($this->countryIdCache[$code])) return $this->countryIdCache[$code];
        $stmt = $this->db->prepare("SELECT id FROM countries WHERE iso_code = ? OR iso2 = ? LIMIT 1");
        $stmt->execute([$code, $code]);
        $row = $stmt->fetch();
        $id = $row ? (int) $row['id'] : null;
        $this->countryIdCache[$code] = $id;
        return $id;
    }

    private function getActiveCountryCodes(): array
    {
        $stmt = $this->db->query("SELECT iso_code FROM countries WHERE is_active = 1");
        return array_column($stmt->fetchAll(), 'iso_code');
    }

    private function updateIndicatorMeta(int $intlIndicatorId): void
    {
        $this->db->prepare("UPDATE international_indicators SET last_fetched_at = NOW() WHERE id = ?")->execute([$intlIndicatorId]);
    }

    private function logResult(string $sourceType, string $indicatorCode, string $status, int $fetched, int $inserted, string $message, float $startTime): array
    {
        $executionMs = (int) ((microtime(true) - $startTime) * 1000);
        try {
            $stmt = $this->db->prepare("INSERT INTO external_fetch_logs (source_type, indicator_code, status, records_fetched, records_inserted, error_message, execution_time_ms) VALUES (?, ?, ?, ?, ?, ?, ?)");
            $stmt->execute([$sourceType, $indicatorCode, $status, $fetched, $inserted, $status === 'error' ? $message : null, $executionMs]);
        } catch (Exception $e) {
            error_log("Log write error: " . $e->getMessage());
        }
        return ['success' => $status === 'success', 'fetched' => $fetched, 'inserted' => $inserted, 'message' => $message, 'time_ms' => $executionMs];
    }
}