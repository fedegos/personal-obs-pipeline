"""Unit tests for bank extractors using in-memory fixtures (no S3)."""

import io

import pandas as pd
import pytest

from bank_extractors import get_extractor, list_extractors

# --- Visa fixture: CSV with ; sep, columns expected by visa_extractor ---
VISA_CSV = (
    "Fecha Origen;Establecimiento;Importe;Moneda;Numero Comprobante;Numero Tarjeta\n"
    "15/01/2025;SUPER 01/03;100.50;$;12345;**** 1234\n"
    "16/01/2025;FARMACIA;250.00;ARS;12346;**** 1234\n"
)


# --- BBVA fixture: minimal Excel (header at row 2, columns Fecha y hora, Monto, Movimientos, Cuota) ---
def _make_bbva_excel_bytes():
    df = pd.DataFrame(
        {
            "Fecha y hora": ["15/01/25", "16/01/25"],
            "Monto": ["$1.500,50", "$2.000,00"],
            "Movimientos": ["SUPER", "FARMACIA"],
            "Cuota": ["-", "-"],
        }
    )
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as w:
        df.to_excel(w, index=False, startrow=2)
    buf.seek(0)
    return buf.read()


class TestListAndGetExtractor:
    """Registry and lookup."""

    def test_list_extractors_returns_names(self):
        names = list_extractors()
        assert "visa" in names
        assert "bbva" in names
        assert "amex" in names

    def test_get_extractor_visa_callable(self):
        fn = get_extractor("visa")
        assert callable(fn)

    def test_get_extractor_unknown_raises(self):
        with pytest.raises(ValueError, match="no encontrado"):
            get_extractor("unknown_bank")


class TestVisaExtractor:
    """Visa extractor with CSV bytes fixture."""

    def test_extract_visa_returns_dataframe(self):
        extract = get_extractor("visa")
        df = extract(VISA_CSV.encode("utf-8"))
        assert isinstance(df, pd.DataFrame)
        assert len(df) >= 1

    def test_extract_visa_has_required_columns(self):
        extract = get_extractor("visa")
        df = extract(VISA_CSV.encode("utf-8"))
        for col in ["fecha_transaccion", "detalles", "monto", "moneda", "red"]:
            assert col in df.columns

    def test_extract_visa_monto_numeric(self):
        extract = get_extractor("visa")
        df = extract(VISA_CSV.encode("utf-8"))
        assert pd.api.types.is_numeric_dtype(df["monto"])
        assert (df["monto"] > 0).all()

    def test_extract_visa_red_is_visa(self):
        extract = get_extractor("visa")
        df = extract(VISA_CSV.encode("utf-8"))
        assert (df["red"] == "Visa").all()


class TestBbvaExtractor:
    """BBVA extractor with Excel bytes fixture."""

    def test_extract_bbva_returns_dataframe(self):
        extract = get_extractor("bbva")
        content = _make_bbva_excel_bytes()
        df = extract(
            content,
            card_number="XXXX 3640",
            card_network="MC",
        )
        assert isinstance(df, pd.DataFrame)
        assert len(df) >= 1

    def test_extract_bbva_has_required_columns(self):
        extract = get_extractor("bbva")
        content = _make_bbva_excel_bytes()
        df = extract(content, card_number="X", card_network="MC")
        for col in ["fecha_transaccion", "detalles", "monto", "moneda", "red", "numero_tarjeta"]:
            assert col in df.columns

    def test_extract_bbva_monto_positive(self):
        extract = get_extractor("bbva")
        content = _make_bbva_excel_bytes()
        df = extract(content, card_number="X", card_network="MC")
        assert (df["monto"] > 0).all()
