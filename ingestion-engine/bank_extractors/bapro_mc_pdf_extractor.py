"""
Extractor para liquidaciones MasterCard del BAPRO.

Layout esperado:
- Header con vencimiento: "V encimiento actual: DD-Mon-YY"
- Sección "DETALLE DEL MES" con bloques (COMPRAS/DEBITOS/CUOTAS)
- Línea transacción: "DD-Mon-YY <detalle> <cupon(5|6)> <monto>"
"""

import re

import pandas as pd

from . import register_extractor
from .pdf.base import PdfExtractorBase
from .pdf.utils import MONTH_EN_TO_NUM, mes_es_to_en, normalize_fecha_mes_es, normalize_monto

_DETALLE_INI_RE = re.compile(r"\bDETALLE DEL MES\b", re.IGNORECASE)
_DETALLE_END_RE = re.compile(r"\b(TOTAL TITULAR|INFORMACION INSTITUCIONAL)\b", re.IGNORECASE)
_SECTION_RE = re.compile(r"^(COMPRAS DEL MES|DEBITOS AUTOMATICOS|CUOTAS DEL MES)\s*$", re.IGNORECASE)
_HEADER_SKIP_RE = re.compile(
    r"^(FECHA\s+NRO\s+CUPON\s+PESOS\s+DOLARES|R ?ESUMEN CONSOLIDADO|SALDO ACTUAL|PAGO MINIMO)\b",
    re.IGNORECASE,
)
_LINE_RE = re.compile(
    r"^(?P<fecha>\d{1,2}-[A-Za-z]{3}-\d{2})\s+(?P<detalles>.+?)\s+(?P<cupon>\d{5,6})\s+(?P<monto>[\d.,]+)\s*$"
)
_CUOTA_RE = re.compile(r"\b(\d{2}/\d{2})\b")
_VENCIMIENTO_ACTUAL_RE = re.compile(
    r"V\s*encimiento actual:\s*(\d{1,2})-([A-Za-z]{3})-(\d{2,4})\b", re.IGNORECASE
)


class BaproMastercardPdfExtractor(PdfExtractorBase):
    extractor_id = "bapro_pdf_mastercard"
    default_network = "Mastercard"

    def _extract_fecha_vencimiento(self, text: str, **kwargs) -> str | None:
        m = _VENCIMIENTO_ACTUAL_RE.search(text)
        if not m:
            return None

        day = int(m.group(1))
        month_raw = m.group(2)
        year_raw = int(m.group(3))
        year = 2000 + year_raw if year_raw < 100 else year_raw

        month_en = mes_es_to_en(month_raw, strict=False) or month_raw[:3].capitalize()
        month_num = MONTH_EN_TO_NUM.get(month_en)
        if month_num is None:
            return None

        return f"{year:04d}-{month_num:02d}-{day:02d}"

    def _postprocess_fecha(self, fecha_str: str) -> str:
        return normalize_fecha_mes_es(fecha_str)

    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        rows: list[dict] = []
        in_detalle = False
        current_section = ""

        for raw_line in text.split("\n"):
            line = raw_line.strip()
            if not line:
                continue

            if not in_detalle:
                if _DETALLE_INI_RE.search(line):
                    in_detalle = True
                continue

            if _DETALLE_END_RE.search(line):
                break
            if _HEADER_SKIP_RE.search(line):
                continue

            sec = _SECTION_RE.match(line)
            if sec:
                current_section = sec.group(1).upper()
                continue

            m = _LINE_RE.match(line)
            if not m:
                continue

            fecha = normalize_fecha_mes_es(m.group("fecha"))
            detalles = m.group("detalles").strip()
            cupon = m.group("cupon")
            monto = normalize_monto(m.group("monto"))
            if monto <= 0:
                continue

            # En estos resúmenes, los consumos con "(USA," suelen venir informados en dólares.
            moneda = "dolares" if "(USA," in detalles.upper() else "pesos"

            en_cuotas = False
            descripcion_cuota = None
            if current_section == "CUOTAS DEL MES":
                cuota_m = _CUOTA_RE.search(detalles)
                if cuota_m:
                    en_cuotas = True
                    descripcion_cuota = cuota_m.group(1)

            rows.append(
                {
                    "fecha_transaccion": fecha,
                    "monto": monto,
                    "detalles": detalles,
                    "moneda": moneda,
                    "numero_operacion": cupon,
                    "en_cuotas": en_cuotas,
                    "descripcion_cuota": descripcion_cuota,
                }
            )

        return rows


_extractor = BaproMastercardPdfExtractor()


def _parse_transactions_from_text(text: str) -> list[dict]:
    """Compatibilidad con tests. Parsea texto BAPRO MasterCard a lista de transacciones."""
    return _extractor._parse_transactions(text)


@register_extractor("bapro_pdf_mastercard")
def extract_bapro_pdf_mastercard(file_content: bytes, **kwargs) -> pd.DataFrame:
    """Extrae movimientos de liquidaciones MasterCard BAPRO en PDF."""
    return _extractor.extract(file_content, **kwargs)
