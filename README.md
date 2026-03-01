# Makroekonomik Dashboard

TCMB EVDS API üzerinden Türkiye ekonomik verilerini çeken, analiz eden ve interaktif grafiklerle sunan full-stack uygulama.

## Mimari

```
┌─────────────────────┐     ┌──────────────┐     ┌─────────────┐
│  Flutter App         │────▶│  PHP Backend  │────▶│    MySQL     │
│  ┌───────────────┐  │     │  (REST API)   │     │  (Veri       │
│  │ ChartConfig   │  │     └──────┬───────┘     │   Deposu)    │
│  │ Builder (Dart)│  │            │              └─────────────┘
│  └───────────────┘  │            │ HTTP (opsiyonel)
│  ┌───────────────┐  │   ┌────────▼────────┐
│  │ Plotly.js     │  │   │ Python Servis    │
│  │ (WebView)     │  │   │ (FastAPI +       │
│  └───────────────┘  │   │  Pandas/NumPy)   │
└─────────────────────┘   └─────────────────┘
```

| Katman | Teknoloji | Görev |
|--------|-----------|-------|
| Frontend | Flutter + Plotly.js (WebView) | İnteraktif grafikler, dashboard |
| Grafik Config | Dart (ChartConfigBuilder) | Plotly.js JSON config üretimi (yerel) |
| Backend API | PHP 8.2 (PDO) | REST API, veri yönetimi, EVDS entegrasyonu |
| Analiz | Python 3.12 (FastAPI + Pandas) | Korelasyon, trend, istatistik **(opsiyonel)** |
| Veritabanı | MySQL 8.0 | Zaman serisi depolama |

### Veri Akışı

**Grafik gösterimi:**
```
Kullanıcı karta tıklar
  → Flutter, PHP API'den zaman serisi verisini çeker
  → ChartConfigBuilder (Dart) Plotly JSON config üretir
  → WebView'da Plotly.js grafiği render eder
```

**İstatistiksel analiz (Python opsiyonel):**
```
Kullanıcı "Analiz Et" tıklar
  → PHP API, Python servisine proxy yapar
  → Python korelasyon/trend hesaplar
  → Sonuç Flutter'a döner
  → Python çalışmıyorsa grafik yine gösterilir, sadece analiz kartı eksik kalır
```

### Cron (otomatik veri güncelleme)

```bash
# Her gün 09:00'da tüm göstergeleri güncelle
0 9 * * * /usr/bin/php /path/to/cron/fetch_data.php --verbose >> /var/log/macro-dashboard.log 2>&1
```

## API Endpoints

### PHP Backend

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `?action=categories` | Kategori listesi |
| GET | `?action=indicators&category=1` | Gösterge listesi |
| GET | `?action=data&id=1&period=1y` | Zaman serisi verisi |
| GET | `?action=compare&ids=1,2&period=5y` | Çoklu gösterge karşılaştırma |
| GET | `?action=latest` | Dashboard özet (son değerler) |
| GET | `?action=search&q=enflasyon` | Gösterge arama |
| POST | `?action=analyze` | Python analiz proxy |
| GET | `?action=stats` | Sistem istatistikleri |

### Python Servisi

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | `/analyze` | Korelasyon, trend, istatistik analizi |
| GET | `/health` | Servis sağlık kontrolü |