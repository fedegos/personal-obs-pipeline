"""Tests for BBVA PDF extractor (resúmenes de tarjetas en PDF)."""

import pandas as pd

from bank_extractors import get_extractor

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
