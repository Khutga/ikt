"""
ChartBuilder - Plotly.js Grafik Konfigürasyon Üreticisi

Bu servis, Flutter WebView'da Plotly.js ile render edilecek
grafik konfigürasyonlarını JSON olarak üretir.

Üretilen JSON, Flutter tarafında şu şekilde kullanılır:
    1. WebView yüklenir (plotly.js dahil)
    2. Python'dan gelen JSON config JavaScript'e aktarılır
    3. Plotly.newPlot('chart', config.data, config.layout, config.config) çağrılır
    4. İnteraktif grafik render edilir (zoom, pan, hover)

Desteklenen Grafik Tipleri:
    - line: Çizgi grafik (zaman serisi)
    - area: Alan grafik (dolgu ile çizgi)
    - bar: Çubuk grafik
    - scatter: Saçılım grafiği (korelasyon görselleştirme)
    - heatmap: Isı haritası (korelasyon matrisi)
"""

import pandas as pd
import numpy as np
from typing import Optional


# Renk paleti - dashboard'da tutarlı renkler
COLORS = [
    "#FF6B6B",  # Kırmızı
    "#4ECDC4",  # Turkuaz
    "#45B7D1",  # Açık mavi
    "#96CEB4",  # Yeşil
    "#FFEAA7",  # Sarı
    "#DDA0DD",  # Mor
    "#98D8C8",  # Mint
    "#F7DC6F",  # Altın
    "#85C1E9",  # Gök mavi
    "#F1948A",  # Somon
]


class ChartBuilder:
    """Plotly.js grafik konfigürasyonu üretici"""

    def build(
        self,
        chart_type: str,
        series_data: list,
        title: str = "",
        overlay: bool = False,
        normalize: bool = False,
        params: dict = {},
    ) -> dict:
        """
        Ana build fonksiyonu. Grafik tipine göre uygun config üretir.
        
        Returns:
            Plotly.js uyumlu dict: {data, layout, config}
        """
        match chart_type:
            case "line":
                return self._line_chart(series_data, title, overlay, normalize, params)
            case "area":
                return self._area_chart(series_data, title, normalize, params)
            case "bar":
                return self._bar_chart(series_data, title, params)
            case "scatter":
                return self._scatter_chart(series_data, title, params)
            case "heatmap":
                return self._heatmap_chart(series_data, title, params)
            case _:
                return self._line_chart(series_data, title, overlay, normalize, params)

    # =========================================
    # ÇİZGİ GRAFİK
    # =========================================

    def _line_chart(
        self, series_data: list, title: str, overlay: bool, normalize: bool, params: dict
    ) -> dict:
        """
        Çizgi grafik - zaman serisi gösterimi
        Overlay: Birden fazla seriyi aynı grafikte gösterir
        Normalize: Farklı birimlerdeki serileri 0-100 arasına normalize eder
        """
        traces = []

        for i, series in enumerate(series_data):
            dates = [d["date"] for d in series["data"]]
            values = [float(d["value"]) for d in series["data"]]

            if normalize and len(values) > 0:
                min_val = min(values)
                max_val = max(values)
                range_val = max_val - min_val
                if range_val > 0:
                    values = [(v - min_val) / range_val * 100 for v in values]

            color = COLORS[i % len(COLORS)]
            name = series.get("name", f"Seri {i+1}")
            unit = series.get("unit", "")

            trace = {
                "type": "scatter",
                "mode": "lines",
                "name": name,
                "x": dates,
                "y": values,
                "line": {"color": color, "width": 2},
                "hovertemplate": f"{name}<br>Tarih: %{{x}}<br>Değer: %{{y:.2f}} {unit}<extra></extra>",
            }

            # Overlay modda ikinci seri y2 eksenine
            if overlay and i > 0:
                trace["yaxis"] = "y2"

            traces.append(trace)

        # Layout
        layout = self._base_layout(title)

        if overlay and len(series_data) > 1:
            layout["yaxis"] = {
                "title": series_data[0].get("name", ""),
                "titlefont": {"color": COLORS[0]},
                "tickfont": {"color": COLORS[0]},
            }
            layout["yaxis2"] = {
                "title": series_data[1].get("name", ""),
                "titlefont": {"color": COLORS[1]},
                "tickfont": {"color": COLORS[1]},
                "overlaying": "y",
                "side": "right",
            }
        elif normalize:
            layout["yaxis"] = {"title": "Normalize Değer (0-100)"}

        return {"data": traces, "layout": layout, "config": self._base_config()}

    # =========================================
    # ALAN GRAFİK
    # =========================================

    def _area_chart(self, series_data: list, title: str, normalize: bool, params: dict) -> dict:
        """Alan grafik - çizgi altı dolgulu"""
        traces = []

        for i, series in enumerate(series_data):
            dates = [d["date"] for d in series["data"]]
            values = [float(d["value"]) for d in series["data"]]
            color = COLORS[i % len(COLORS)]

            traces.append({
                "type": "scatter",
                "mode": "lines",
                "name": series.get("name", f"Seri {i+1}"),
                "x": dates,
                "y": values,
                "fill": "tozeroy" if i == 0 else "tonexty",
                "line": {"color": color, "width": 1},
                "fillcolor": color.replace(")", ", 0.3)").replace("rgb", "rgba")
                    if "rgb" in color else color + "4D",  # %30 opacity
            })

        return {"data": traces, "layout": self._base_layout(title), "config": self._base_config()}

    # =========================================
    # ÇUBUK GRAFİK
    # =========================================

    def _bar_chart(self, series_data: list, title: str, params: dict) -> dict:
        """
        Çubuk grafik
        Aylık/yıllık değişim gösterimi için ideal
        """
        traces = []

        for i, series in enumerate(series_data):
            dates = [d["date"] for d in series["data"]]
            values = [float(d["value"]) for d in series["data"]]
            color = COLORS[i % len(COLORS)]

            # Pozitif/negatif renklendirme (tek seri ise)
            if len(series_data) == 1:
                colors = ["#4ECDC4" if v >= 0 else "#FF6B6B" for v in values]
            else:
                colors = color

            traces.append({
                "type": "bar",
                "name": series.get("name", f"Seri {i+1}"),
                "x": dates,
                "y": values,
                "marker": {"color": colors},
            })

        layout = self._base_layout(title)
        if len(series_data) > 1:
            layout["barmode"] = "group"

        return {"data": traces, "layout": layout, "config": self._base_config()}

    # =========================================
    # SAÇILIM GRAFİĞİ (Korelasyon)
    # =========================================

    def _scatter_chart(self, series_data: list, title: str, params: dict) -> dict:
        """
        Saçılım grafiği - iki gösterge arasındaki ilişkiyi gösterir
        Korelasyon analizi sonucu ile birlikte kullanılır
        """
        if len(series_data) < 2:
            return self._line_chart(series_data, title, False, False, params)

        # İki seriyi hizala
        df_a = pd.DataFrame(series_data[0]["data"])
        df_b = pd.DataFrame(series_data[1]["data"])
        df_a["date"] = pd.to_datetime(df_a["date"])
        df_b["date"] = pd.to_datetime(df_b["date"])
        df_a["value"] = pd.to_numeric(df_a["value"], errors="coerce")
        df_b["value"] = pd.to_numeric(df_b["value"], errors="coerce")

        merged = pd.merge(df_a, df_b, on="date", suffixes=("_a", "_b")).dropna()

        x_vals = merged["value_a"].tolist()
        y_vals = merged["value_b"].tolist()
        dates = merged["date"].dt.strftime("%Y-%m-%d").tolist()

        name_a = series_data[0].get("name", "X")
        name_b = series_data[1].get("name", "Y")

        # Ana scatter trace
        traces = [{
            "type": "scatter",
            "mode": "markers",
            "name": f"{name_a} vs {name_b}",
            "x": x_vals,
            "y": y_vals,
            "text": dates,
            "marker": {
                "color": COLORS[0],
                "size": 6,
                "opacity": 0.7,
            },
            "hovertemplate": f"Tarih: %{{text}}<br>{name_a}: %{{x:.2f}}<br>{name_b}: %{{y:.2f}}<extra></extra>",
        }]

        # Trend çizgisi ekle
        if len(x_vals) > 2:
            z = np.polyfit(x_vals, y_vals, 1)
            p = np.poly1d(z)
            x_line = [min(x_vals), max(x_vals)]
            y_line = [p(x) for x in x_line]

            traces.append({
                "type": "scatter",
                "mode": "lines",
                "name": "Trend",
                "x": x_line,
                "y": y_line,
                "line": {"color": "#FF6B6B", "width": 2, "dash": "dash"},
            })

        layout = self._base_layout(title or f"{name_a} vs {name_b}")
        layout["xaxis"]["title"] = f"{name_a} ({series_data[0].get('unit', '')})"
        layout["yaxis"] = {"title": f"{name_b} ({series_data[1].get('unit', '')})"}

        return {"data": traces, "layout": layout, "config": self._base_config()}

    # =========================================
    # ISI HARİTASI (Korelasyon Matrisi)
    # =========================================

    def _heatmap_chart(self, series_data: list, title: str, params: dict) -> dict:
        """
        Korelasyon matrisi ısı haritası
        Birden fazla gösterge arasındaki korelasyonları gösterir
        """
        if len(series_data) < 2:
            return self._line_chart(series_data, title, False, False, params)

        # DataFrame'leri oluştur ve birleştir
        dfs = {}
        for series in series_data:
            name = series.get("name", series.get("code", "?"))
            df = pd.DataFrame(series["data"])
            df["date"] = pd.to_datetime(df["date"])
            df["value"] = pd.to_numeric(df["value"], errors="coerce")
            df = df.set_index("date")
            dfs[name] = df["value"]

        combined = pd.DataFrame(dfs).dropna()

        if len(combined) < 5:
            raise ValueError("Korelasyon matrisi için yetersiz veri")

        # Korelasyon matrisi
        corr_matrix = combined.corr()
        labels = list(corr_matrix.columns)

        traces = [{
            "type": "heatmap",
            "z": corr_matrix.values.tolist(),
            "x": labels,
            "y": labels,
            "colorscale": [
                [0.0, "#FF6B6B"],   # -1: Kırmızı (negatif)
                [0.5, "#FFFFFF"],    #  0: Beyaz
                [1.0, "#4ECDC4"],   # +1: Yeşil (pozitif)
            ],
            "zmin": -1,
            "zmax": 1,
            "text": [[f"{v:.3f}" for v in row] for row in corr_matrix.values],
            "texttemplate": "%{text}",
            "hovertemplate": "%{x} vs %{y}<br>Korelasyon: %{z:.3f}<extra></extra>",
        }]

        layout = self._base_layout(title or "Korelasyon Matrisi")
        layout["height"] = max(400, len(labels) * 80)

        return {"data": traces, "layout": layout, "config": self._base_config()}

    # =========================================
    # ORTAK LAYOUT & CONFIG
    # =========================================

    def _base_layout(self, title: str) -> dict:
        """Tüm grafiklerde kullanılan temel layout"""
        return {
            "title": {
                "text": title,
                "font": {"size": 16, "color": "#333"},
                "x": 0.05,
            },
            "xaxis": {
                "title": "",
                "showgrid": True,
                "gridcolor": "#f0f0f0",
                "rangeslider": {"visible": False},  # Flutter'da yer kaplar, kapalı başla
            },
            "yaxis": {
                "showgrid": True,
                "gridcolor": "#f0f0f0",
                "zeroline": True,
                "zerolinecolor": "#ddd",
            },
            "legend": {
                "orientation": "h",
                "yanchor": "bottom",
                "y": 1.02,
                "xanchor": "right",
                "x": 1,
            },
            "margin": {"l": 60, "r": 60, "t": 60, "b": 50},
            "paper_bgcolor": "white",
            "plot_bgcolor": "white",
            "hovermode": "x unified",
            "font": {"family": "Inter, sans-serif"},
        }

    def _base_config(self) -> dict:
        """Plotly.js interaktivite ayarları"""
        return {
            "responsive": True,
            "displayModeBar": True,
            "modeBarButtonsToRemove": [
                "lasso2d", "select2d", "autoScale2d",
            ],
            "displaylogo": False,
            "locale": "tr",
            "scrollZoom": True,
        }