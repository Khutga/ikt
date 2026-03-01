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

