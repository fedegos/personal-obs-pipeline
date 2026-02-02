"""
Extractor para liquidaciones Visa del BAPRO (Banco de la Provincia de Buenos Aires).
Procesa PDFs y devuelve DataFrame con columnas estándar.

Formato BAPRO: fecha en columnas año/mes/día con forward-fill.
- Fecha completa: YY Mes DD CUPON [*|K|P|Q|V] DESCRIPCIÓN MONTO
- Fecha abreviada (mismo mes/año): DD CUPON [*|K|P|Q|V] DESCRIPCIÓN MONTO
"""

import io
import re

import pandas as pd
import pdfplumber

from utils.data_standardizer import apply_standard_format

from . import register_extractor

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

_SKIP_PATTERNS = (
    r"SU PAGO EN PESOS",
    r"TOTAL CONSUMOS",
    r"SALDO ACTUAL",
    r"IMPUESTO DE SELLOS",
    r"IIBB PERCEP",
    r"IVA RG",
    r"DB\.RG",
    r"BONIF\.",
    r"Prox\.Cierre",
    r"Cierre Ant\.",
    r"Prox\.Vto\.",
    r"Vto\. Ant\.",
)

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

_CUOTA_RE = re.compile(r"C\.(\d{1,2})/(\d{1,2})\b", re.IGNORECASE)
_USD_IN_LINE_RE = re.compile(r"\bUSD\s+([\d.,]+)", re.IGNORECASE)
_AMOUNT_RE = re.compile(r"([\d.,]+)-?\s*$")
_MESES_VALIDOS = set(_MES_ES_A_EN.keys()) | {m.rstrip(".") for m in _MES_ES_A_EN.keys()}


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


def _mes_to_english(mes: str) -> str:
    """Convierte mes en español a formato para pd.to_datetime."""
    m = mes.rstrip(".").capitalize()
    for es, en in _MES_ES_A_EN.items():
        if m.lower().startswith(es.lower()[:4]):
            return en
    return mes


def _extract_cuota_info(detalles: str) -> tuple[bool, str]:
    """Detecta si es consumo en cuotas (C.XX/YY) y extrae descripcion_cuota."""
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
    """Extrae transacciones del texto del PDF. Forward-fill de año/mes."""
    rows = []
    current_year = None
    current_month = None

    for line in text.split("\n"):
        line = line.strip()
        if not line or _should_skip_line(line):
            continue

        amount_m = _AMOUNT_RE.search(line)
        if not amount_m:
            continue
        monto_raw = amount_m.group(1)
        monto_val = _normalize_monto(monto_raw)
        if monto_val <= 0:
            continue

        is_negative = line.rstrip().endswith("-")
        if is_negative:
            continue

        rest = line[: amount_m.start()].strip()
        if not rest:
            continue

        parts = rest.split(None, 4)
        if len(parts) < 4:
            continue

        year, month, day = None, None, None
        cupon = None
        detalles = ""

        if parts[1] in _MESES_VALIDOS or parts[1].rstrip(".") in _MESES_VALIDOS:
            year = parts[0]
            month = _mes_to_english(parts[1])
            day = parts[2]
            cupon = parts[3]
            if len(parts) >= 5:
                detalles = parts[4]
            current_year = year
            current_month = month
        else:
            if current_year is None or current_month is None:
                continue
            day = parts[0]
            cupon = parts[1]
            year = current_year
            month = current_month
            # Incluir parts[2] por si el flag está pegado a la primera palabra (*PROVINCIA)
            if len(parts) >= 4:
                detalles = " ".join(parts[2:])

        if not cupon or not cupon.isdigit():
            continue
        if not day.isdigit() or not year.isdigit():
            continue

        year_int = int(year)
        full_year = 2000 + year_int if year_int < 100 else year_int
        fecha_str = f"{int(day):02d}-{month}-{full_year % 100:02d}"

        try:
            pd.to_datetime(fecha_str, format="%d-%b-%y")
        except (ValueError, TypeError):
            continue

        usd_in_line = _USD_IN_LINE_RE.search(line)
        if usd_in_line:
            moneda = "dolares"
            monto_final = _normalize_monto(usd_in_line.group(1))
        else:
            moneda = "pesos"
            monto_final = monto_val

        if monto_final <= 0:
            continue

        detalles = detalles.strip()
        # Quitar el flag: * siempre; K/P/Q/V solo cuando es token separado (seguido de espacio)
        # Así preservamos PATAGONIA, PROPINA, *PROVINCIA (quitamos solo el *)
        if detalles.startswith("*"):
            detalles = detalles[1:].lstrip()
        elif len(detalles) >= 2 and detalles[0] in "KPQV" and detalles[1] in " \t":
            detalles = detalles[1:].lstrip()

        en_cuotas, descripcion_cuota = _extract_cuota_info(detalles)

        rows.append(
            {
                "fecha_transaccion": fecha_str,
                "monto": monto_final,
                "detalles": detalles,
                "moneda": moneda,
                "numero_operacion": cupon,
                "en_cuotas": en_cuotas,
                "descripcion_cuota": descripcion_cuota,
            }
        )

    return rows


def _normalize_fecha_bapro(fecha_str: str) -> str:
    """Convierte DD-MMM-YY a formato parseable por pandas."""
    for es, en in _MES_ES_A_EN.items():
        fecha_str = re.sub(rf"\b{es}\b", en, fecha_str, flags=re.IGNORECASE)
    return fecha_str


@register_extractor("bapro_pdf_visa")
def extract_bapro_pdf_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """
    Extrae movimientos de liquidaciones Visa BAPRO en PDF.
    Formato: YY Mes DD / DD (forward-fill) + CUPON + DESCRIPCIÓN + MONTO.
    """
    empty_df = pd.DataFrame(columns=REQUIRED_COLUMNS)

    if not file_content or len(file_content) < 100:
        print(
            f"⚠️ bapro_pdf_visa: archivo vacío o demasiado pequeño ({len(file_content) if file_content else 0} bytes)"
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
                f"⚠️ bapro_pdf_visa: no se pudo extraer texto del PDF ({len(text) if text else 0} caracteres)."
            )
            return empty_df

        rows = _parse_transactions_from_text(text)

        if not rows:
            sample = text[:500].replace("\n", " ")
            print(f"⚠️ bapro_pdf_visa: 0 transacciones encontradas. Muestra: {sample[:200]}...")
            return empty_df

        df = pd.DataFrame(rows)
        for col in REQUIRED_COLUMNS:
            if col not in df.columns:
                df[col] = None
        df["red"] = kwargs.get("card_network", "Visa")
        df["numero_tarjeta"] = kwargs.get("card_number")
        df["fecha_transaccion"] = df["fecha_transaccion"].apply(_normalize_fecha_bapro)
        df = df[[c for c in REQUIRED_COLUMNS]]

        df = df[df["monto"].notna() & (df["monto"] > 0)]
        if df.empty:
            print("⚠️ bapro_pdf_visa: todas las filas filtradas (monto=0 o NaN)")
            return empty_df
        return apply_standard_format(df)
    except Exception as e:
        print(f"❌ bapro_pdf_visa error: {e}")
        import traceback

        traceback.print_exc()
        return empty_df
