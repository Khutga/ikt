"""
Makroekonomik Dashboard - Python Analiz Mikroservisi

FastAPI ile çalışan hafif bir analiz servisi.
PHP backend'den gelen zaman serisi verilerini analiz eder.

Endpoints:
    POST /analyze          → Ana analiz endpoint'i (korelasyon, trend, istatistik)
    GET  /health           → Servis sağlık kontrolü

Not: Grafik config üretimi artık Flutter tarafında (ChartConfigBuilder) yapılıyor.
     Bu servis sadece istatistiksel analiz içindir.

Çalıştırma:
    pip install fastapi uvicorn pandas numpy scipy
    uvicorn app.main:app --host 0.0.0.0 --port 8001 --reload
"""

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional

from services.analyzer import AnalyzerService

# =========================================
# UYGULAMA AYARLARI
# =========================================

app = FastAPI(
    title="Macro Dashboard - Analiz Servisi",
    description="Ekonomik veri analizi (korelasyon, trend, istatistik)",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

analyzer = AnalyzerService()


# =========================================
# MODELLER
# =========================================

class DataPoint(BaseModel):
    date: str
    value: float


class SeriesInput(BaseModel):
    indicator_id: int
    name: str
    code: str = ""
    unit: str = ""
    data: list[DataPoint]


class AnalyzeRequest(BaseModel):
    type: str  # correlation, trend, statistics, comparison, moving_avg
    indicator_ids: list[int]
    period: str = "5y"
    series_data: list[SeriesInput]
    params: Optional[dict] = {}


# =========================================
# ENDPOINTS
# =========================================

@app.get("/health")
def health_check():
    """Servis sağlık kontrolü"""
    return {"status": "ok", "service": "macro-dashboard-analyzer", "version": "1.1.0"}


@app.post("/analyze")
def analyze(request: AnalyzeRequest):
    """
    Ana analiz endpoint'i

    Desteklenen analiz tipleri:
    - correlation: İki gösterge arasındaki korelasyon (Pearson, Spearman)
    - trend: Trend analizi (lineer regresyon, eğim, yön)
    - statistics: Temel istatistikler (ortalama, medyan, std, min, max)
    - comparison: İki gösterge karşılaştırması
    - moving_avg: Hareketli ortalama hesaplama
    """
    try:
        series_list = [s.model_dump() for s in request.series_data]

        result = match_analysis_type(
            analysis_type=request.type,
            series_data=series_list,
            params=request.params or {},
        )

        return {"success": True, "analysis_type": request.type, "result": result}

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Analiz hatası: {str(e)}")


# =========================================
# ANALİZ ROUTER
# =========================================

def match_analysis_type(analysis_type: str, series_data: list, params: dict) -> dict:
    """Analiz tipine göre doğru servisi çağırır"""

    match analysis_type:
        case "correlation":
            if len(series_data) < 2:
                raise ValueError("Korelasyon için en az 2 gösterge gerekli")
            return analyzer.correlation(series_data[0], series_data[1], params)

        case "trend":
            return analyzer.trend_analysis(series_data[0], params)

        case "statistics":
            results = []
            for series in series_data:
                results.append(analyzer.descriptive_stats(series))
            return results if len(results) > 1 else results[0]

        case "comparison":
            if len(series_data) < 2:
                raise ValueError("Karşılaştırma için en az 2 gösterge gerekli")
            return analyzer.comparison(series_data[0], series_data[1], params)

        case "moving_avg":
            window = params.get("window", 30)
            return analyzer.moving_average(series_data[0], window=window)

        case _:
            raise ValueError(f"Desteklenmeyen analiz tipi: {analysis_type}")


# =========================================
# ANA ÇALIŞTIRMA
# =========================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001, reload=True)