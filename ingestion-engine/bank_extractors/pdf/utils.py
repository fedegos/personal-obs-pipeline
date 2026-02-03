"""
Utilidades compartidas para extractores PDF.

DRY: normalización de montos, conversión de meses español→inglés,
extracción de cuotas, helpers de fechas.
"""

import re
from typing import Optional

import pandas as pd

# Meses español → inglés (variantes abreviadas y completas)
MES_ES_A_EN: dict[str, str] = {
    # Abreviados (BBVA, BAPRO)
    "Ene": "Jan",
    "Feb": "Feb",
    "Mar": "Mar",
    "Abr": "Apr",
    "May": "May",
    "Jun": "Jun",
    "Jul": "Jul",
    "Ago": "Aug",
    "Sep": "Sep",
    "Setiem": "Sep",
    "Setiembre": "Sep",
    "Oct": "Oct",
    "Octubre": "Oct",
    "Nov": "Nov",
    "Noviem": "Nov",
    "Noviembre": "Nov",
    "Dic": "Dec",
    "Diciem": "Dec",
    "Diciembre": "Dec",
    # Completos (AMEX)
    "Enero": "Jan",
    "Febrero": "Feb",
    "Marzo": "Mar",
    "Abril": "Apr",
    "Mayo": "May",
    "Junio": "Jun",
    "Julio": "Jul",
    "Agosto": "Aug",
    "Septiembre": "Sep",
}

MONTH_EN_TO_NUM: dict[str, int] = {
    "Jan": 1,
    "Feb": 2,
    "Mar": 3,
    "Apr": 4,
    "May": 5,
    "Jun": 6,
    "Jul": 7,
    "Aug": 8,
    "Sep": 9,
    "Oct": 10,
    "Nov": 11,
    "Dec": 12,
}


def normalize_monto(value) -> float:
    """Convierte string de monto (ej: '39.178,91' o '1.500,50') a float."""
    if pd.isna(value):
        return float("nan")
    s = str(value).strip()
    s = re.sub(r"[^\d,.\-]", "", s)
    s = s.replace(".", "").replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return float("nan")


def mes_es_to_en(mes: str, strict: bool = False) -> Optional[str]:
    """
    Convierte mes en español a inglés para pd.to_datetime.
    strict=True: retorna None si no encuentra (AMEX).
    strict=False: retorna el mes original si no encuentra (BAPRO).
    """
    m = mes.strip().rstrip(".").capitalize()
    for es, en in MES_ES_A_EN.items():
        if m.lower().startswith(es.lower()[:4]):
            return en
    return None if strict else mes


def normalize_fecha_mes_es(fecha_str: str, mes_map: Optional[dict[str, str]] = None) -> str:
    """Reemplaza meses en español por inglés en DD-MMM-YY para pandas."""
    mapping = mes_map or MES_ES_A_EN
    for es, en in mapping.items():
        fecha_str = re.sub(rf"\b{re.escape(es)}\b", en, fecha_str, flags=re.IGNORECASE)
    return fecha_str


def extract_cuota_c_xx_yy(detalles: str) -> tuple[bool, str]:
    """Detecta cuotas C.XX/YY (BAPRO, BBVA). Retorna (en_cuotas, descripcion_cuota)."""
    m = re.search(r"C\.(\d{1,2})/(\d{1,2})\b", detalles, re.IGNORECASE)
    if m:
        return True, f"{m.group(1)}/{m.group(2)}"
    return False, "-"


def extract_cuota_amex(detalles: str) -> tuple[bool, str]:
    """Detecta cuotas CUOTA XX/YY DE ... (AMEX). Retorna (en_cuotas, descripcion_cuota)."""
    m = re.search(r"CUOTA\s+(\d{1,2})/(\d{1,2})\s+DE\s+[\d.,]+", detalles, re.IGNORECASE)
    if m:
        return True, f"{int(m.group(1)):02d}/{int(m.group(2)):02d}"
    return False, "-"


def deduce_year(trans_month: int, trans_day: int, billing_month: int, billing_year: int) -> int:
    """
    Deducir año según mes del período de facturación.
    Si mes_trans <= mes_período → año_período.
    Si mes_trans > mes_período → año_período - 1.
    """
    if trans_month <= billing_month:
        return billing_year
    return billing_year - 1


def extract_year_from_filename(
    filename: Optional[str], pattern: str = r"(\d{4})-\d{2}-\d{2}"
) -> Optional[int]:
    """Extrae año del filename. Por defecto YYYY-MM-DD."""
    if not filename:
        return None
    m = re.search(pattern, filename)
    return int(m.group(1)) if m else None


def should_skip_text(text: str, patterns: tuple[str, ...]) -> bool:
    """True si el texto coincide con algún patrón de exclusión."""
    for pat in patterns:
        if re.search(pat, text, re.IGNORECASE):
            return True
    return False
