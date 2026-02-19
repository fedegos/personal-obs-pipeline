"""
Extractor para resúmenes de tarjetas BBVA en formato PDF (Visa/Mastercard).
Formato: DD-MMM-YY DESCRIPCIÓN CUPÓN PESOS [DÓLARES]
"""

import re

import pandas as pd

from . import register_extractor
from .pdf.base import PdfExtractorBase
from .pdf.utils import (
    extract_cuota_c_xx_yy,
    extract_fecha_vencimiento_pattern,
    normalize_fecha_mes_es,
    normalize_monto,
    should_skip_text,
)

_VTO_CIERRE_RE = re.compile(
    r"(?:Vto\.|Vencimiento|Cierre)\s*[:\s]*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})",
    re.IGNORECASE,
)
# BBVA tabla: header "VENCIMIENTO ACTUAL" y luego línea con "DD-MMM-YY DD-MMM-YY" (2º = vto)
_DD_MMM_YY_RE = re.compile(r"(\d{2}-[A-Za-z]{3}-\d{2})\s+(\d{2}-[A-Za-z]{3}-\d{2})")

_SKIP_PATTERNS = (
    r"SU PAGO EN PESOS",
    r"TOTAL CONSUMOS",
    r"SALDO ACTUAL",
    r"IIBB PERCEP",
    r"IVA RG",
)

_TRANSACTION_RE = re.compile(
    r"^(\d{2}-[A-Za-z]{3}-\d{2})\s+(.+?)\s+(\d{6})\s+([\d.,]+)(?:\s+([\d.,]+))?\s*$",
    re.MULTILINE,
)
_TRANSACTION_USD_EMPTY_PESOS_RE = re.compile(
    r"^(\d{2}-[A-Za-z]{3}-\d{2})\s+(.+?)\s+(\d{6})\s{2,}([\d.,]+)\s*$",
    re.MULTILINE,
)
_USD_IN_LINE_RE = re.compile(r"\bUSD\s+([\d.,]+)", re.IGNORECASE)


class BbvaPdfExtractor(PdfExtractorBase):
    extractor_id = "bbva_pdf_visa"
    default_network = "Visa"

    def _extract_fecha_vencimiento(self, text: str, **kwargs) -> str | None:
        """Extrae Vto./Vencimiento/Cierre. Formatos: DD/MM/YY o tabla 'VENCIMIENTO ACTUAL' + DD-MMM-YY."""
        result = extract_fecha_vencimiento_pattern(text, _VTO_CIERRE_RE)
        if result:
            return result
        idx = text.upper().find("VENCIMIENTO ACTUAL")
        if idx >= 0:
            after_header = text[idx:]
            for line in after_header.split("\n")[1:]:  # saltar la línea del header
                m = _DD_MMM_YY_RE.search(line)
                if m:
                    dd_mmm_yy = m.group(2)
                    normalized = normalize_fecha_mes_es(dd_mmm_yy)
                    try:
                        dt = pd.to_datetime(normalized, format="%d-%b-%y")
                        return dt.strftime("%Y-%m-%d")
                    except (ValueError, TypeError):
                        continue
        return None

    def _postprocess_fecha(self, fecha_str: str) -> str:
        return normalize_fecha_mes_es(fecha_str)

    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        rows = []
        for line in text.split("\n"):
            line = line.strip()
            if not line or should_skip_text(line, _SKIP_PATTERNS):
                continue

            m_empty_pesos = _TRANSACTION_USD_EMPTY_PESOS_RE.match(line)
            if m_empty_pesos:
                fecha_str, detalles, cupon, monto_dolares = m_empty_pesos.groups()
                monto_final = normalize_monto(monto_dolares)
                if monto_final <= 0:
                    continue
                en_cuotas, descripcion_cuota = extract_cuota_c_xx_yy(detalles.strip())
                rows.append(
                    {
                        "fecha_transaccion": fecha_str,
                        "monto": monto_final,
                        "detalles": detalles.strip(),
                        "moneda": "dolares",
                        "numero_operacion": cupon,
                        "en_cuotas": en_cuotas,
                        "descripcion_cuota": descripcion_cuota,
                    }
                )
                continue

            m = _TRANSACTION_RE.match(line)
            if not m:
                continue

            fecha_str, detalles, cupon, monto_pesos, monto_dolares = m.groups()
            monto_val = normalize_monto(monto_pesos)
            monto_usd = normalize_monto(monto_dolares) if monto_dolares else 0.0
            usd_in_line = _USD_IN_LINE_RE.search(line)
            if usd_in_line:
                monto_usd = normalize_monto(usd_in_line.group(1))

            if usd_in_line and monto_usd > 0:
                moneda = "dolares"
                monto_final = monto_usd
            elif monto_val > 0:
                moneda = "pesos"
                monto_final = monto_val
            elif monto_usd > 0:
                moneda = "dolares"
                monto_final = monto_usd
            else:
                continue

            en_cuotas, descripcion_cuota = extract_cuota_c_xx_yy(detalles.strip())
            rows.append(
                {
                    "fecha_transaccion": fecha_str,
                    "monto": monto_final,
                    "detalles": detalles.strip(),
                    "moneda": moneda,
                    "numero_operacion": cupon,
                    "en_cuotas": en_cuotas,
                    "descripcion_cuota": descripcion_cuota,
                }
            )
        return rows


_extractor = BbvaPdfExtractor()


def _parse_transactions_from_text(text: str) -> list[dict]:
    """Compatibilidad con tests. Parsea texto BBVA a lista de transacciones."""
    return _extractor._parse_transactions(text)


@register_extractor("bbva_pdf_visa")
def extract_bbva_pdf_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """Extrae movimientos de resumen BBVA en PDF (Visa)."""
    return _extractor.extract(file_content, **kwargs)
