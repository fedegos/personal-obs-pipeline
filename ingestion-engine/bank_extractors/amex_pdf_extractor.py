"""
Extractor para resúmenes AMEX (no bancaria) en formato PDF.
Formato: bloques separados por guiones bajos.
- Línea 1: DD de Mes MONTO
- Línea 2: DESCRIPCIÓN [CUOTA XX/YY DE total]
- REFERENCIA numero
"""

import re

import pandas as pd

from . import register_extractor
from .pdf.base import PdfExtractorBase
from .pdf.utils import (
    MONTH_EN_TO_NUM,
    deduce_year,
    extract_cuota_amex,
    extract_year_from_filename,
    mes_es_to_en,
    normalize_monto,
    should_skip_text,
)

_SKIP_PATTERNS = (
    r"Detalle mes anterior",
    r"Vencimiento",
    r"Pago Min",
    r"Fecha y detalle",
    r"Saldo Anterior",
    r"Estado de Cuenta",
    r"Facturación",
    r"Movimientos del Período",
    r"INTERESES FINANCIEROS",
    r"IVA\s+21%",
)

_BLOCK_SEP_RE = re.compile(r"_+")
_DATE_AMOUNT_RE = re.compile(r"^(\d{1,2})\s+de\s+(\w+)\s+([\d.,]+)$")
_REFERENCIA_RE = re.compile(r"REFERENCIA\s+(\d+)", re.IGNORECASE)
_BILLING_PERIOD_RE = re.compile(r"ARGENTINA\s+\d+\s+\S+\s+(\d{2})/(\d{2})\b")
_BILLING_DATE_FALLBACK_RE = re.compile(r"\b(\d{2})/(\d{2})/(\d{2})\b")


def _extract_billing_period(text: str) -> tuple[int, int] | None:
    """Extrae período de facturación MM/AA de la primera página."""
    first_page = text.split("\f")[0] if "\f" in text else text[:5000]
    m = _BILLING_PERIOD_RE.search(first_page)
    if m:
        mm, aa = int(m.group(1)), int(m.group(2))
        year = 2000 + aa if aa < 100 else aa
        return (mm, year)
    for m in _BILLING_DATE_FALLBACK_RE.finditer(first_page):
        dd, mm, yy = int(m.group(1)), int(m.group(2)), int(m.group(3))
        if 1 <= mm <= 12 and dd <= 31:
            year = 2000 + yy if yy < 100 else yy
            return (mm, year)
    return None


class AmexPdfExtractor(PdfExtractorBase):
    extractor_id = "amex_pdf"
    default_network = "Amex"

    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        billing_period = kwargs.get("billing_period")
        filename_year = extract_year_from_filename(kwargs.get("filename")) or kwargs.get("year")

        if billing_period is None:
            billing_period = _extract_billing_period(text)
        if billing_period is None and filename_year:
            billing_period = (12, filename_year)
        billing_month, billing_year = billing_period or (12, filename_year or 2025)

        rows = []
        blocks = _BLOCK_SEP_RE.split(text)
        for block in blocks:
            block = block.strip()
            if not block or should_skip_text(block, _SKIP_PATTERNS):
                continue

            lines = [ln.strip() for ln in block.split("\n") if ln.strip()]
            if len(lines) < 2:
                continue

            date_m = _DATE_AMOUNT_RE.match(lines[0])
            if not date_m:
                continue

            day, month_es, amount_raw = date_m.groups()
            month_en = mes_es_to_en(month_es, strict=True)
            if not month_en:
                continue

            monto = normalize_monto(amount_raw)
            if monto <= 0 or pd.isna(monto):
                continue

            detalles = lines[1]
            en_cuotas, descripcion_cuota = extract_cuota_amex(detalles)

            ref_m = _REFERENCIA_RE.search(block)
            numero_operacion = ref_m.group(1) if ref_m else ""

            trans_month = MONTH_EN_TO_NUM.get(month_en, 1)
            year = deduce_year(trans_month, int(day), billing_month, billing_year)
            fecha_str = f"{int(day):02d}-{month_en}-{year % 100:02d}"

            try:
                pd.to_datetime(fecha_str, format="%d-%b-%y")
            except (ValueError, TypeError):
                continue

            rows.append(
                {
                    "fecha_transaccion": fecha_str,
                    "monto": monto,
                    "detalles": detalles,
                    "moneda": "pesos",
                    "numero_operacion": numero_operacion,
                    "en_cuotas": en_cuotas,
                    "descripcion_cuota": descripcion_cuota,
                }
            )
        return rows


_extractor = AmexPdfExtractor()


def _parse_transactions_from_text(
    text: str,
    billing_period: tuple[int, int] | None = None,
    filename_year: int | None = None,
) -> list[dict]:
    """Compatibilidad con tests. Parsea texto AMEX a lista de transacciones."""
    return _extractor._parse_transactions(
        text, billing_period=billing_period, filename_year=filename_year
    )


@register_extractor("amex_pdf")
def extract_amex_pdf(file_content: bytes, **kwargs) -> pd.DataFrame:
    """Extrae movimientos de resúmenes AMEX en PDF."""
    return _extractor.extract(file_content, **kwargs)
