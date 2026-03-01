# Makroekonomik Dashboard

TCMB EVDS API üzerinden Türkiye ekonomik verilerini çeken, analiz eden ve interaktif grafiklerle sunan full-stack uygulama.

## Mimari

```
┌────────────────┐     ┌──────────────┐     ┌─────────────┐
│  Flutter App   │────▶│  PHP Backend  │────▶│    MySQL     │
│  (WebView +    │     │  (REST API)   │     │  (Veri       │
│   Plotly.js)   │     └──────┬───────┘     │   Deposu)    │
└────────────────┘            │              └─────────────┘
                              │ HTTP
                     ┌────────▼────────┐
                     │ Python Servis    │
                     │ (FastAPI +       │
                     │  Pandas/NumPy)   │
                     └─────────────────┘
```

| Katman | Teknoloji | Görev |
|--------|-----------|-------|
| Frontend | Flutter + Plotly.js (WebView) | İnteraktif grafikler, dashboard |
| Backend API | PHP 8.2 (PDO) | REST API, veri yönetimi, EVDS entegrasyonu |
| Analiz | Python 3.12 (FastAPI + Pandas) | Korelasyon, trend, istatistik |
| Veritabanı | MySQL 8.0 | Zaman serisi depolama |

## Hızlı Başlangıç

### 1. EVDS API Key

[TCMB EVDS](https://evds2.tcmb.gov.tr/) sitesinden ücretsiz API key alın.

### 2 Enter to the virtual environment.To enter to virtual environment, run the command: 

source /home/seyidzade/virtualenv/python-service/3.11/bin/activate && cd /home/seyidzade/python-service

### 3. Manuel Kurulum

**MySQL:**
```bash
mysql -u root -p < backend-php/schema.sql
```

**PHP:**
```bash
cd backend-php
cp config/config.php config/config.local.php
# config.local.php içine DB ve API bilgilerini yazın
# Apache/Nginx ile backend-php klasörünü serve edin
```

**Python:**
```bash
cd python-service
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
```

**Flutter:**
```bash
cd flutter_app
flutter pub get
flutter run
```

## API Endpoints

### PHP Backend (port 8080)

| Endpoint | Açıklama |
|----------|----------|
| `GET /api.php?action=categories` | Kategori listesi |
| `GET /api.php?action=indicators&category=1` | Gösterge listesi |
| `GET /api.php?action=data&id=1&period=5y` | Zaman serisi verisi |
| `GET /api.php?action=compare&ids=1,2&period=5y` | Karşılaştırma verisi |
| `GET /api.php?action=latest` | Dashboard özet (son değerler) |
| `GET /api.php?action=search&q=enflasyon` | Arama |
| `POST /api.php?action=analyze` | Analiz (Python proxy) |

### Python Servis (port 8001)

| Endpoint | Açıklama |
|----------|----------|
| `GET /health` | Sağlık kontrolü |
| `POST /analyze` | Korelasyon, trend, istatistik analizi |
| `POST /chart-config` | Plotly.js grafik konfigürasyonu |

## Cron Job Kurulumu

```bash
# Hafta içi döviz kurları (her gün 18:00)
0 18 * * 1-5 /usr/bin/php /path/to/cron/fetch_data.php --frequency=daily --verbose

# Aylık veriler (her ayın 5'i saat 10:00)
0 10 5 * * /usr/bin/php /path/to/cron/fetch_data.php --frequency=monthly --verbose

# Tüm veriler (her gün 09:00)
0 9 * * * /usr/bin/php /path/to/cron/fetch_data.php --verbose
```

## Proje Yapısı

```
macro-dashboard/
├── backend-php/
│   ├── config/
│   │   ├── config.php          # Yapılandırma
│   │   └── Database.php        # PDO Singleton
│   ├── services/
│   │   └── EvdsService.php     # EVDS API entegrasyonu
│   ├── cron/
│   │   └── fetch_data.php      # Otomatik veri güncelleme
│   ├── api.php                 # REST API controller
│   └── schema.sql              # Veritabanı şeması + seed data
├── python-service/
│   ├── app/
│   │   └── main.py             # FastAPI uygulama
│   ├── services/
│   │   ├── analyzer.py         # İstatistiksel analiz motoru
│   │   └── chart_builder.py    # Plotly grafik config üreticisi
│   ├── requirements.txt
│   └── Dockerfile
├── flutter_app/
│   ├── lib/
│   │   ├── config/
│   │   │   └── app_config.dart
│   │   ├── models/
│   │   │   └── models.dart
│   │   ├── services/
│   │   │   └── api_service.dart
│   │   ├── screens/
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── chart_screen.dart
│   │   │   ├── comparison_screen.dart
│   │   │   └── search_screen.dart
│   │   ├── widgets/
│   │   │   ├── plotly_chart.dart
│   │   │   └── common_widgets.dart
│   │   └── main.dart
│   └── pubspec.yaml
├── docker-compose.yml
├── .env.example
└── README.md
```

## Göstergeler (30+ seri)

- **Fiyat & Enflasyon:** TÜFE, ÜFE, Gıda Enflasyonu, Enflasyon Beklentisi
- **Para Politikası:** Politika Faizi, Fonlama Maliyeti, Gecelik Faiz
- **Döviz & Altın:** USD/TRY, EUR/TRY, GBP/TRY, CHF/TRY, JPY/TRY
- **Büyüme & Üretim:** GSYİH, Sanayi Üretim Endeksi, Kapasite Kullanım
- **İstihdam:** İşsizlik Oranı, İşgücüne Katılım
- **Dış Ticaret:** İhracat, İthalat, Cari Denge
- **Finansal:** BIST 100, Tahvil Faizi
- **Güven Endeksleri:** Tüketici Güveni, Reel Kesim Güveni

## Lisans

MIT