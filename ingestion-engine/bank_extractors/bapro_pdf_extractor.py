"""
Extractor para liquidaciones Visa del BAPRO (Banco de la Provincia de Buenos Aires).
Formato: fecha con forward-fill.
- Fecha completa: YY Mes DD CUPON [*|K|P|Q|V] DESCRIPCIÓN MONTO
- Fecha abreviada: DD CUPON [*|K|P|Q|V] DESCRIPCIÓN MONTO
"""

import re

import pandas as pd

from . import register_extractor
from .pdf.base import PdfExtractorBase
from .pdf.utils import (
    MES_ES_A_EN,
    extract_cuota_c_xx_yy,
    mes_es_to_en,
    normalize_fecha_mes_es,
    normalize_monto,
    should_skip_text,
)

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
    r"\bVENCIMIENTO\b",
    r"\bCIERRE\b",
)

_CUOTA_RE = re.compile(r"C\.(\d{1,2})/(\d{1,2})\b", re.IGNORECASE)
_USD_IN_LINE_RE = re.compile(r"\bUSD\s+([\d.,]+)", re.IGNORECASE)
_AMOUNT_RE = re.compile(r"([\d.,]+)-?\s*$")
_MESES_VALIDOS = set(MES_ES_A_EN.keys()) | {m.rstrip(".") for m in MES_ES_A_EN.keys()}


class BaproPdfExtractor(PdfExtractorBase):
    extractor_id = "bapro_pdf_visa"
    default_network = "Visa"

    def _postprocess_fecha(self, fecha_str: str) -> str:
        return normalize_fecha_mes_es(fecha_str)

    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        rows = []
        current_year = None
        current_month = None

        for line in text.split("\n"):
            line = line.strip()
            if not line or should_skip_text(line, _SKIP_PATTERNS):
                continue

            amount_m = _AMOUNT_RE.search(line)
            if not amount_m:
                continue
            monto_val = normalize_monto(amount_m.group(1))
            if monto_val <= 0:
                continue

            if line.rstrip().endswith("-"):
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
                month = mes_es_to_en(parts[1], strict=False)
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
                if len(parts) >= 4:
                    detalles = " ".join(parts[2:])

            if not cupon or not cupon.isdigit():
                continue
            if len(cupon) != 6:
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
                monto_final = normalize_monto(usd_in_line.group(1))
            else:
                moneda = "pesos"
                monto_final = monto_val

            if monto_final <= 0:
                continue

            detalles = detalles.strip()
            if detalles.startswith("*"):
                detalles = detalles[1:].lstrip()
            elif len(detalles) >= 2 and detalles[0] in "KPQV" and detalles[1] in " \t":
                detalles = detalles[1:].lstrip()

            en_cuotas, descripcion_cuota = extract_cuota_c_xx_yy(detalles)

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


_extractor = BaproPdfExtractor()


def _parse_transactions_from_text(text: str) -> list[dict]:
    """Compatibilidad con tests. Parsea texto BAPRO a lista de transacciones."""
    return _extractor._parse_transactions(text)


@register_extractor("bapro_pdf_visa")
def extract_bapro_pdf_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """Extrae movimientos de liquidaciones Visa BAPRO en PDF."""
    return _extractor.extract(file_content, **kwargs)
