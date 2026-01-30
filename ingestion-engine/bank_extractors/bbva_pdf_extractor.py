"""
Extractor para resúmenes de tarjetas BBVA en formato PDF.
Procesa PDFs de resumen (Visa/Mastercard) y devuelve DataFrame con columnas estándar.
"""

import io
import re

import pandas as pd
import pdfplumber

from utils.data_standardizer import apply_standard_format

from . import register_extractor

# Columnas requeridas por el pipeline (main.py, data_standardizer)
REQUIRED_COLUMNS = ["fecha_transaccion", "monto", "detalles", "moneda", "red", "numero_operacion"]


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


@register_extractor("bbva_pdf_visa")
def extract_bbva_pdf_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """
    Extrae movimientos de un resumen BBVA en PDF (Visa).
    Devuelve DataFrame con fecha_transaccion, monto, detalles, moneda, red, numero_operacion.
    Si el PDF está vacío o no tiene tablas, devuelve DataFrame vacío con las columnas.
    """
    empty_df = pd.DataFrame(columns=REQUIRED_COLUMNS)

    if not file_content or len(file_content) < 100:
        return empty_df

    try:
        with pdfplumber.open(io.BytesIO(file_content)) as pdf:
            rows = []
            for page in pdf.pages:
                tables = page.extract_tables()
                for table in tables or []:
                    if not table or len(table) < 2:
                        continue
                    # Primera fila como header; buscar columnas por nombre o posición
                    header = [str(c).strip().lower() if c else "" for c in table[0]]
                    for data_row in table[1:]:
                        if not data_row or all(c is None or str(c).strip() == "" for c in data_row):
                            continue
                        row_dict = _row_to_standard(header, data_row)
                        if row_dict:
                            rows.append(row_dict)

            if not rows:
                return empty_df

            df = pd.DataFrame(rows)
            if df.empty:
                return empty_df
            if "numero_operacion" not in df.columns:
                df["numero_operacion"] = range(len(df))
            for col in REQUIRED_COLUMNS:
                if col not in df.columns:
                    df[col] = None
            df = df[[c for c in REQUIRED_COLUMNS if c in df.columns]]
            if "moneda" not in df.columns:
                df["moneda"] = "pesos"
            if "red" not in df.columns:
                df["red"] = kwargs.get("card_network", "Visa")

            df["monto"] = df["monto"].apply(_normalize_monto)
            df = df[df["monto"].notna() & (df["monto"] > 0)]
            if df.empty:
                return empty_df
            return apply_standard_format(df)
    except Exception:
        return empty_df


def _row_to_standard(header: list, data_row: list) -> dict | None:
    """Mapea una fila de tabla a un dict con fecha_transaccion, monto, detalles."""
    # Mapeos comunes: fecha (fecha, date), detalle (detalle, movimientos, descripción), monto (monto, importe)
    row = {}
    for i, h in enumerate(header):
        if i >= len(data_row):
            break
        val = data_row[i]
        if val is None or (isinstance(val, str) and not val.strip()):
            continue
        val = str(val).strip()
        if "fecha" in h or "date" in h:
            row["fecha_transaccion"] = val
        elif "detalle" in h or "movimiento" in h or "descripcion" in h or "establecimiento" in h:
            row["detalles"] = val
        elif "monto" in h or "importe" in h:
            row["monto"] = val
    if "monto" in row and ("detalles" in row or "fecha_transaccion" in row):
        row.setdefault("detalles", "")
        row.setdefault("fecha_transaccion", pd.NaT)
        return row
    return None
