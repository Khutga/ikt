# Makroekonomik Dashboard

TCMB EVDS API üzerinden Türkiye ekonomik verilerini analiz eden ve interaktif grafiklerle sunan full-stack uygulama. Akademik ekonometrik analiz modülü ile tez çalışmalarını destekler.

## Mimari

```
┌─────────────────────┐     ┌──────────────────┐     ┌─────────────┐
│  Flutter App         │────▶│  PHP Backend      │────▶│   MySQL      │
│                      │     │  ┌────────────┐  │     │  data_points │
│  Dashboard           │     │  │EvdsService │  │     │  intl_data   │
│  Grafik & Analiz     │     │  │WorldBank   │  │     │  countries   │
│  Ülke Kıyaslama      │     │  │  Service   │  │     └─────────────┘
│  Ekonometri          │     │  └─────┬──────┘  │
│  Sürdürülebilirlik   │     │        │ proxy   │
│  Sözlük              │     └────────┼─────────┘
└─────────────────────┘              │
                              ┌──────▼──────────┐
                              │  Python Servis   │
                              │  FastAPI         │
                              │  Ekonometri      │
                              │  İstatistik      │
                              └─────────────────┘
```

| Katman | Teknoloji | Görev |
|--------|-----------|-------|
| Frontend | Flutter + Plotly.js (WebView) | Dashboard, grafikler, ekonometri UI |
| Backend | PHP 8.2 (PDO) | REST API, EVDS/WorldBank entegrasyonu |
| Analiz | Python 3.12 (FastAPI) | Ekonometrik analiz, istatistik |
| Veritabanı | MySQL 8.0 | Zaman serisi depolama |

## API Endpoints

### PHP Backend (`api.php`)

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| GET | `?action=categories` | Kategori listesi |
| GET | `?action=indicators&category=1` | Gösterge listesi |
| GET | `?action=data&id=1&period=1y` | Zaman serisi verisi |
| GET | `?action=compare&ids=1,2&period=5y` | Çoklu gösterge karşılaştırma |
| GET | `?action=latest` | Dashboard özet (son değerler) |
| GET | `?action=search&q=enflasyon` | Gösterge arama |
| GET | `?action=countries` | Ülke listesi |
| GET | `?action=intl_compare&indicator=1&countries=TUR,USA` | Ülke kıyaslama |
| GET | `?action=sustainability&countries=TUR,USA,DEU` | Yeşil göstergeler |
| POST | `?action=analyze` | İstatistiksel analiz (Python proxy) |
| POST | `?action=econometrics` | Ekonometrik analiz (Python proxy) |

### Python Servisi (`/econometrics`)

| Method | Endpoint | Açıklama |
|--------|----------|----------|
| POST | `/econometrics` | Ekonometrik analiz |
| POST | `/analyze` | Korelasyon, trend, istatistik |
| GET | `/econometrics/methods` | Desteklenen yöntemler |
| GET | `/health` | Servis durumu |

## Ekonometrik Analiz Modülü

Tez: *"Sürdürülebilir Kalkınma Sürecinde Yeşil Ekonomiye Geçişin Rolü: AB ve Türkiye"*

### Desteklenen Yöntemler

| Yöntem | Açıklama | Kütüphane |
|--------|----------|-----------|
| `unit_root` | ADF, PP, KPSS birim kök testleri | statsmodels |
| `cointegration` | Engle-Granger, Johansen eşbütünleşme | statsmodels |
| `granger` | Granger nedensellik testi | statsmodels |
| `var_model` | VAR + IRF + Varyans Ayrıştırma | statsmodels |
| `ardl` | Pesaran ARDL sınır testi | statsmodels |
| `garch` | ARCH/GARCH volatilite modeli | arch |
| `ols` | OLS regresyon + diagnostik testler | statsmodels |
| `descriptive` | Tanımlayıcı istatistik (tez tablosu) | scipy |
| `correlation` | Pearson, Spearman, kısmi korelasyon | pingouin |
| `full_analysis` | Tam tez paketi (hepsi bir arada) | — |

### Kullanım Örneği

```json
POST /econometrics
{
  "method": "unit_root",
  "series_data": [{
    "indicator_id": 1,
    "name": "TÜFE",
    "unit": "%",
    "data": [{"date": "2024-01-01", "value": 64.77}, ...]
  }],
  "params": {"regression": "ct"}
}
```

### Tez Analiz Akışı

```
1. descriptive    → Tablo 5.1: Tanımlayıcı İstatistikler
2. unit_root      → Tablo 5.2: ADF ve KPSS Birim Kök Sonuçları
3. cointegration  → Tablo 5.3: Johansen Eşbütünleşme Sonuçları
4. granger        → Tablo 5.4: Granger Nedensellik Sonuçları
5. var_model      → Şekil 5.1: Etki-Tepki Fonksiyonları (IRF)
6. garch          → Tablo 5.5: GARCH Model Sonuçları
7. ols            → Tablo 5.6: Regresyon Analizi Sonuçları
```

## Veri Kaynakları

| Kaynak | Veri | Frekans |
|--------|------|---------|
| TCMB EVDS | Enflasyon, faiz, döviz, üretim, istihdam | Günlük/Aylık |
| Dünya Bankası | GDP, CO₂, yenilenebilir enerji, orman alanı | Yıllık |

## Cron (Otomatik Güncelleme)

```bash
# Günlük TCMB verileri (her gün 09:00)
0 9 * * * php fetch_data.php --verbose

# Haftalık uluslararası veriler (her Pazartesi 10:00)
0 10 * * 1 php fetch_international.php --verbose
```