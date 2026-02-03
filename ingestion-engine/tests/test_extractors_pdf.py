"""Tests for BBVA, BAPRO and AMEX PDF extractors (resúmenes de tarjetas en PDF)."""

import pandas as pd
import pytest

from bank_extractors import get_extractor
from bank_extractors.amex_pdf_extractor import _parse_transactions_from_text as _parse_amex
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


class TestAmexPdfExtractor:
    """AMEX PDF extractor: bloques DD de Mes MONTO, descripción, REFERENCIA."""

    def test_get_extractor_amex_pdf_returns_callable(self):
        fn = get_extractor("amex_pdf")
        assert callable(fn)

    def test_extract_amex_pdf_returns_dataframe_with_required_columns(self):
        extract = get_extractor("amex_pdf")
        df = extract(b"")
        assert isinstance(df, pd.DataFrame)
        for col in ["fecha_transaccion", "monto", "detalles"]:
            assert col in df.columns, f"missing column {col}"

    def test_parse_block_with_date_desc_referencia(self):
        """Bloque: 15 de Marzo 45.104,13 + descripción + REFERENCIA."""
        text = """15 de Marzo 45.104,13
MERPAGO*ELECTRONICAFLA CUOTA 04/06 DE 270.624,80
104924332941
REFERENCIA 52082862
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(12, 2025))
        assert len(rows) == 1
        assert rows[0]["fecha_transaccion"] == "15-Mar-25"
        assert rows[0]["monto"] == 45104.13
        assert "MERPAGO*ELECTRONICAFLA" in rows[0]["detalles"]
        assert rows[0]["numero_operacion"] == "52082862"

    def test_parse_cuota_extracts_en_cuotas(self):
        """CUOTA 04/06 DE 270.624,80 → en_cuotas=True, descripcion_cuota=04/06."""
        text = """15 de Marzo 45.104,13
MERPAGO*ELECTRONICAFLA CUOTA 04/06 DE 270.624,80
REFERENCIA 52082862
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(12, 2025))
        assert len(rows) == 1
        assert rows[0]["en_cuotas"] is True
        assert rows[0]["descripcion_cuota"] == "04/06"

    def test_skip_header_blocks(self):
        """Excluye bloques con Detalle mes anterior, Vencimiento, etc."""
        text = """Detalle mes anterior
Vencimiento : 27/11/25
________________________________________________________________________
2 de Abril 7.290,91
MERPAGO*MIGHTS CUOTA 09/12 DE 87.491,00
REFERENCIA 32106302
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(12, 2025))
        assert len(rows) == 1
        assert "Detalle" not in str(rows[0])

    def test_year_deduction_april_with_period_dec25(self):
        """Abril + período 12/25 → Abril 2025."""
        text = """2 de Abril 7.290,91
MERPAGO*MIGHTS CUOTA 09/12 DE 87.491,00
REFERENCIA 32106302
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(12, 2025))
        assert len(rows) == 1
        assert rows[0]["fecha_transaccion"] == "02-Apr-25"

    def test_year_deduction_november_with_period_jan26(self):
        """Noviembre + período 01/26 → Noviembre 2025."""
        text = """15 de Noviembre 12.500,00
CASA DINGO
REFERENCIA 12345
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(1, 2026))
        assert len(rows) == 1
        assert rows[0]["fecha_transaccion"] == "15-Nov-25"

    def test_skip_intereses_financieros_and_iva(self):
        """Excluye INTERESES FINANCIEROS e IVA 21%."""
        text = """15 de Marzo 1.234,56
INTERESES FINANCIEROS (APLICADOS SOBRE SALDOS ACORDADOS IMPAGOS)
REFERENCIA 99991
________________________________________________________________________
20 de Marzo 259,26
IVA 21%
REFERENCIA 99992
________________________________________________________________________
25 de Marzo 5.000,00
MERPAGO*TIENDA CUOTA 01/06 DE 30.000,00
REFERENCIA 52082862
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(12, 2025))
        assert len(rows) == 1
        assert "MERPAGO" in rows[0]["detalles"]
        assert "INTERESES" not in str(rows)
        assert "IVA" not in str(rows)


# --- Tests de regresión con PDFs reales (samples/ está en .gitignore) ---


@pytest.mark.regression
class TestAmexPdfRegression:
    """Regresión: extractor AMEX sobre PDFs reales."""

    def test_amex_sample_returns_valid_dataframe(self):
        import os

        path = os.path.join(
            os.path.dirname(__file__), "..", "samples", "amex", "AMEX 2025-01-21.pdf"
        )
        try:
            with open(path, "rb") as f:
                content = f.read()
        except FileNotFoundError:
            pytest.skip("samples/ no disponible (gitignored)")

        extract = get_extractor("amex_pdf")
        df = extract(content, filename="AMEX 2025-01-21.pdf")
        assert isinstance(df, pd.DataFrame)
        for col in ["fecha_transaccion", "monto", "detalles", "moneda", "red"]:
            assert col in df.columns, f"missing {col}"
        assert len(df) > 0
        assert (df["monto"] > 0).all()
        assert pd.api.types.is_datetime64_any_dtype(df["fecha_transaccion"])
        assert df["red"].iloc[0] == "Amex"


@pytest.mark.regression
class TestBaproPdfRegression:
    """Regresión: extractor BAPRO sobre PDFs reales."""

    def test_bapro_sample_returns_valid_dataframe(self):
        import os

        base = os.path.join(os.path.dirname(__file__), "..", "samples", "bapro")
        files = [f for f in os.listdir(base) if f.endswith(".pdf")] if os.path.isdir(base) else []
        if not files:
            pytest.skip("samples/bapro/ no disponible")
        path = os.path.join(base, files[0])

        with open(path, "rb") as f:
            content = f.read()
        extract = get_extractor("bapro_pdf_visa")
        df = extract(content)
        assert isinstance(df, pd.DataFrame)
        assert "fecha_transaccion" in df.columns
        assert "monto" in df.columns
        assert "detalles" in df.columns
        if len(df) > 0:
            assert (df["monto"] > 0).all()
            assert pd.api.types.is_datetime64_any_dtype(df["fecha_transaccion"])


@pytest.mark.regression
class TestBbvaPdfRegression:
    """Regresión: extractor BBVA sobre PDFs reales."""

    def test_bbva_sample_returns_valid_dataframe(self):
        import os

        base = os.path.join(os.path.dirname(__file__), "..", "samples", "bbva")
        files = [f for f in os.listdir(base) if f.endswith(".pdf")] if os.path.isdir(base) else []
        if not files:
            pytest.skip("samples/bbva/ no disponible")
        path = os.path.join(base, files[0])

        with open(path, "rb") as f:
            content = f.read()
        extract = get_extractor("bbva_pdf_visa")
        df = extract(content)
        assert isinstance(df, pd.DataFrame)
        assert "fecha_transaccion" in df.columns
        assert "monto" in df.columns
        assert "detalles" in df.columns
        if len(df) > 0:
            assert (df["monto"] > 0).all()
            assert pd.api.types.is_datetime64_any_dtype(df["fecha_transaccion"])
