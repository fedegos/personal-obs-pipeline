"""Tests for BBVA and BAPRO PDF extractors (resúmenes de tarjetas en PDF)."""

import pandas as pd

from bank_extractors import get_extractor
from bank_extractors.bapro_pdf_extractor import (
    _parse_transactions_from_text as _parse_bapro,
)
from bank_extractors.bbva_pdf_extractor import _parse_transactions_from_text

# Minimal valid PDF (one empty page). Extractor should return empty DataFrame or parse if table present.
BBVA_PDF_MINIMAL = b"%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000009 00000 n \n0000000052 00000 n \n0000000101 00000 n \ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n178\n%%EOF"


class TestBbvaPdfExtractor:
    """BBVA PDF extractor: DataFrame with fecha_transaccion, monto, detalles."""

    def test_get_extractor_bbva_pdf_visa_returns_callable(self):
        fn = get_extractor("bbva_pdf_visa")
        assert callable(fn)

    def test_extract_bbva_pdf_visa_returns_dataframe_with_required_columns(self):
        extract = get_extractor("bbva_pdf_visa")
        df = extract(BBVA_PDF_MINIMAL)
        assert isinstance(df, pd.DataFrame)
        for col in ["fecha_transaccion", "monto", "detalles"]:
            assert col in df.columns, f"missing column {col}"

    def test_extract_bbva_pdf_visa_minimal_pdf_returns_dataframe(self):
        extract = get_extractor("bbva_pdf_visa")
        df = extract(BBVA_PDF_MINIMAL)
        assert isinstance(df, pd.DataFrame)
        assert (
            "fecha_transaccion" in df.columns and "monto" in df.columns and "detalles" in df.columns
        )

    def test_extract_bbva_pdf_visa_empty_bytes_returns_empty_dataframe(self):
        extract = get_extractor("bbva_pdf_visa")
        df = extract(b"")
        assert isinstance(df, pd.DataFrame)
        assert len(df) == 0
        for col in ["fecha_transaccion", "monto", "detalles"]:
            assert col in df.columns

    def test_extract_bbva_pdf_visa_monto_numeric_when_rows_present(self):
        extract = get_extractor("bbva_pdf_visa")
        df = extract(BBVA_PDF_MINIMAL)
        if len(df) > 0:
            assert pd.api.types.is_numeric_dtype(df["monto"])
            assert (df["monto"] >= 0).all()

    def test_parse_transaction_with_usd_in_line_uses_dolares(self):
        """Columna DÓLARES: PESOS vacío, descripción tiene ' USD 2,99'. Debe ser moneda=dolares."""
        text = "25-Dic-25 STEAMGAMES.COM 4259522985 USD 2,99 497321 2,99"
        rows = _parse_transactions_from_text(text)
        assert len(rows) == 1
        assert rows[0]["moneda"] == "dolares"
        assert rows[0]["monto"] == 2.99
        assert "STEAMGAMES.COM" in rows[0]["detalles"]

    def test_parse_transaction_empty_pesos_column_uses_dolares(self):
        """Columna PESOS vacía deducida por regex: cupón + 2+ espacios + monto → dólares."""
        text = "25-Dic-25 STEAMGAMES.COM 4259522985 USD 2,99 497321  2,99"
        rows = _parse_transactions_from_text(text)
        assert len(rows) == 1
        assert rows[0]["moneda"] == "dolares"
        assert rows[0]["monto"] == 2.99


class TestBaproPdfExtractor:
    """BAPRO PDF extractor: YY Mes DD / DD forward-fill, cupon, desc, monto."""

    def test_get_extractor_bapro_pdf_visa_returns_callable(self):
        fn = get_extractor("bapro_pdf_visa")
        assert callable(fn)

    def test_extract_bapro_pdf_visa_returns_dataframe_with_required_columns(self):
        extract = get_extractor("bapro_pdf_visa")
        df = extract(b"")
        assert isinstance(df, pd.DataFrame)
        for col in ["fecha_transaccion", "monto", "detalles"]:
            assert col in df.columns, f"missing column {col}"

    def test_parse_full_date_extracts_correctly(self):
        """Fecha completa: 25 Agosto 02 080069 * BIGG CABALLITO 92.280,00"""
        text = "25 Agosto 02 080069 * BIGG CABALLITO 000000000201575 92.280,00"
        rows = _parse_bapro(text)
        assert len(rows) == 1
        assert rows[0]["fecha_transaccion"] == "02-Aug-25"
        assert rows[0]["monto"] == 92280.0
        assert rows[0]["moneda"] == "pesos"
        assert "BIGG CABALLITO" in rows[0]["detalles"]
        assert rows[0]["numero_operacion"] == "080069"

    def test_parse_short_date_forward_fill(self):
        """Fecha abreviada (mismo mes/año): tras 25 Agosto 02, línea 05 392588..."""
        text = """25 Agosto 02 080069 * BIGG CABALLITO 92.280,00
05 392588 * RAPPIPRO 5.499,00"""
        rows = _parse_bapro(text)
        assert len(rows) == 2
        assert rows[0]["fecha_transaccion"] == "02-Aug-25"
        assert rows[1]["fecha_transaccion"] == "05-Aug-25"
        assert rows[1]["monto"] == 5499.0
        assert rows[1]["detalles"] == "RAPPIPRO"

    def test_parse_usd_in_line_uses_dolares(self):
        """Línea con USD 2,99 → moneda=dolares. Requiere fecha previa (forward-fill)."""
        text = """26 Enero 01 692343 K MERPAGO*BIGGCABALLITO 98.280,00
28 270795 GOOGLE *Google O P1ib3RMv USD 2,99 2,99"""
        rows = _parse_bapro(text)
        assert len(rows) == 2
        assert rows[1]["moneda"] == "dolares"
        assert rows[1]["monto"] == 2.99

    def test_parse_cuotas_extracts_en_cuotas(self):
        """C.01/06 en detalles → en_cuotas=True, descripcion_cuota=01/06."""
        text = "25 Agosto 09 356791 * YENNY CABALLITO C.01/06 7.658,35"
        rows = _parse_bapro(text)
        assert len(rows) == 1
        assert rows[0]["en_cuotas"] is True
        assert rows[0]["descripcion_cuota"] == "01/06"
        assert "YENNY" in rows[0]["detalles"]

    def test_skip_su_pago_and_iibb(self):
        """Excluye SU PAGO, IIBB PERCEP."""
        text = """25 Agosto 02 080069 * RAPPI 5.499,00
26 Enero 12 SU PAGO EN PESOS 9.014,50-
29 IIBB PERCEP-BSAS 2,00%( 16320,49) 326,40"""
        rows = _parse_bapro(text)
        assert len(rows) == 1
        assert "SU PAGO" not in str(rows)
        assert "IIBB" not in str(rows)
