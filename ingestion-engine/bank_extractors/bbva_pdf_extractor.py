"""
Extractor para resúmenes de tarjetas BBVA en formato PDF.
Procesa PDFs de resumen (Visa/Mastercard) y devuelve DataFrame con columnas estándar.

El layout de BBVA no permite extracción fiable por tablas (pdfplumber.extract_tables).
Se usa extracción por texto y regex para detectar líneas de transacciones con formato:
  DD-MMM-YY DESCRIPCIÓN CUPÓN PESOS [DÓLARES]
"""

import io
import re

import pandas as pd
import pdfplumber

from utils.data_standardizer import apply_standard_format

from . import register_extractor

# Columnas requeridas por el pipeline (main.py, data_standardizer)
REQUIRED_COLUMNS = [
    "fecha_transaccion",
    "monto",
    "detalles",
    "moneda",
    "red",
    "numero_operacion",
    "numero_tarjeta",
    "en_cuotas",
    "descripcion_cuota",
]

# Líneas a excluir (pagos, totales, impuestos)
_SKIP_PATTERNS = (
    r"SU PAGO EN PESOS",
    r"TOTAL CONSUMOS",
    r"SALDO ACTUAL",
    r"IIBB PERCEP",
    r"IVA RG",
)

# Meses BBVA (español) -> inglés para pd.to_datetime
_MES_ES_A_EN = {
    "Ene": "Jan",
    "Feb": "Feb",
    "Mar": "Mar",
    "Abr": "Apr",
    "May": "May",
    "Jun": "Jun",
    "Jul": "Jul",
    "Ago": "Aug",
    "Sep": "Sep",
    "Oct": "Oct",
    "Nov": "Nov",
    "Dic": "Dec",
}

# Regex para cuotas: C.XX/YY indica cuota X de Y (ej: C.02/03 = cuota 2 de 3)
_CUOTA_RE = re.compile(r"C\.(\d{1,2})/(\d{1,2})\b", re.IGNORECASE)

# Regex: DD-MMM-YY ... 6digits monto_pesos [monto_dolares]
# Ej: 04-Oct-25 GREEN GARDEN 004577 27.000,00
# Ej: 25-Dic-25 STEAMGAMES.COM 4259522985 USD 2,99 497321 2,99
_TRANSACTION_RE = re.compile(
    r"^(\d{2}-[A-Za-z]{3}-\d{2})\s+(.+?)\s+(\d{6})\s+([\d.,]+)(?:\s+([\d.,]+))?\s*$",
    re.MULTILINE,
)


def _normalize_monto(value):
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


def _normalize_fecha_bbva(fecha_str: str) -> str:
    """Convierte fecha DD-MMM-YY con mes en español a formato parseable por pandas."""
    for es, en in _MES_ES_A_EN.items():
        fecha_str = re.sub(rf"\b{es}\b", en, fecha_str, flags=re.IGNORECASE)
    return fecha_str


def _extract_cuota_info(detalles: str) -> tuple[bool, str]:
    """Detecta si es consumo en cuotas (C.XX/YY) y extrae descripcion_cuota (XX/YY)."""
    m = _CUOTA_RE.search(detalles)
    if m:
        return True, f"{m.group(1)}/{m.group(2)}"
    return False, "-"


def _should_skip_line(line: str) -> bool:
    """Excluye líneas que no son transacciones de consumo."""
    for pat in _SKIP_PATTERNS:
        if re.search(pat, line, re.IGNORECASE):
            return True
    return False


def _parse_transactions_from_text(text: str) -> list[dict]:
    """Extrae transacciones del texto del PDF usando regex."""
    rows = []
    for line in text.split("\n"):
        line = line.strip()
        if not line or _should_skip_line(line):
            continue
        m = _TRANSACTION_RE.match(line)
        if not m:
            continue
        fecha_str, detalles, cupon, monto_pesos, monto_dolares = m.groups()
        monto_val = _normalize_monto(monto_pesos)
        monto_usd = _normalize_monto(monto_dolares) if monto_dolares else 0.0
        # Priorizar monto en pesos; si es 0 y hay USD, usar dólares
        if monto_val > 0:
            moneda = "pesos"
            monto_final = monto_val
        elif monto_usd > 0:
            moneda = "dolares"
            monto_final = monto_usd
        else:
            continue
        en_cuotas, descripcion_cuota = _extract_cuota_info(detalles.strip())
        rows.append(
            {
                "fecha_transaccion": _normalize_fecha_bbva(fecha_str),
                "monto": monto_final,
                "detalles": detalles.strip(),
                "moneda": moneda,
                "numero_operacion": cupon,
                "en_cuotas": en_cuotas,
                "descripcion_cuota": descripcion_cuota,
            }
        )
    return rows


@register_extractor("bbva_pdf_visa")
def extract_bbva_pdf_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """
    Extrae movimientos de un resumen BBVA en PDF (Visa).
    Devuelve DataFrame con fecha_transaccion, monto, detalles, moneda, red, numero_operacion.
    Usa extracción por texto + regex; las tablas de pdfplumber no capturan el layout de BBVA.
    """
    empty_df = pd.DataFrame(columns=REQUIRED_COLUMNS)

    if not file_content or len(file_content) < 100:
        print(
            f"⚠️ bbva_pdf_visa: archivo vacío o demasiado pequeño ({len(file_content) if file_content else 0} bytes)"
        )
        return empty_df

    try:
        full_text = []
        with pdfplumber.open(io.BytesIO(file_content)) as pdf:
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    full_text.append(t)
        text = "\n".join(full_text)

        if not text or len(text.strip()) < 50:
            print(
                f"⚠️ bbva_pdf_visa: no se pudo extraer texto del PDF ({len(text) if text else 0} caracteres). ¿Es un PDF escaneado/imagen?"
            )
            return empty_df

        rows = _parse_transactions_from_text(text)

        if not rows:
            # Muestra un fragmento del texto para diagnosticar si el formato es distinto
            sample = text[:500].replace("\n", " ")
            print(
                f"⚠️ bbva_pdf_visa: 0 transacciones encontradas. Texto extraído ({len(text)} chars). Muestra: {sample[:200]}..."
            )
            return empty_df

        df = pd.DataFrame(rows)
        for col in REQUIRED_COLUMNS:
            if col not in df.columns:
                df[col] = None
        df["red"] = kwargs.get("card_network", "Visa")
        # numero_tarjeta: si no figura en el PDF, debe venir como parámetro (card_number) en el upload
        df["numero_tarjeta"] = kwargs.get("card_number")
        df = df[[c for c in REQUIRED_COLUMNS]]

        df = df[df["monto"].notna() & (df["monto"] > 0)]
        if df.empty:
            print("⚠️ bbva_pdf_visa: todas las filas filtradas (monto=0 o NaN)")
            return empty_df
        return apply_standard_format(df)
    except Exception as e:
        print(f"❌ bbva_pdf_visa error: {e}")
        import traceback

        traceback.print_exc()
        return empty_df
