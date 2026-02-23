"""Tests for BBVA, BAPRO and AMEX PDF extractors (resúmenes de tarjetas en PDF)."""

import pandas as pd
import pytest

from bank_extractors import get_extractor
from bank_extractors.amex_pdf_extractor import _parse_transactions_from_text as _parse_amex
from bank_extractors.bapro_mc_pdf_extractor import (
    _parse_transactions_from_text as _parse_bapro_mc,
)
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

    def test_extract_fecha_vencimiento_vto_format(self):
        """Vto. 15/02/26 → 2026-02-15."""
        from bank_extractors.bbva_pdf_extractor import _extractor

        text = "Vto. 15/02/26\n25-Dic-25 STEAM 497321 100,00"
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2026-02-15"

    def test_extract_fecha_vencimiento_cierre_format(self):
        """Cierre 10/01/26 → 2026-01-10."""
        from bank_extractors.bbva_pdf_extractor import _extractor

        text = "Cierre 10/01/26\nResumen de cuenta"
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2026-01-10"

    def test_extract_fecha_vencimiento_vencimiento_actual_table(self):
        """Tabla BBVA: VENCIMIENTO ACTUAL + línea con DD-MMM-YY → 2ª columna."""
        from bank_extractors.bbva_pdf_extractor import _extractor

        text = """CIERRE ACTUAL VENCIMIENTO ACTUAL SALDO ACTUAL
30-Oct-25 07-Nov-25 558.786,73"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-11-07"


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

    def test_extract_fecha_vencimiento_prox_vto_full_date(self):
        """Prox.Vto. 15/03/26 → 2026-03-15."""
        from bank_extractors.bapro_pdf_extractor import _extractor

        text = """Prox.Vto. 15/03/26
25 Agosto 02 080069 * RAPPI 5.499,00"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2026-03-15"

    def test_extract_fecha_vencimiento_prox_vto_dd_mm_uses_default_year(self):
        """Prox.Vto. 15/03 sin año → usa año del texto (25) o filename."""
        from bank_extractors.bapro_pdf_extractor import _extractor

        text = """Prox.Vto. 15/03
25 Agosto 02 080069 * RAPPI 5.499,00"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-03-15"

    def test_extract_fecha_vencimiento_prox_vto_with_year_kwarg(self):
        """Prox.Vto. 15/03 usa year de kwargs cuando el texto no tiene transacciones."""
        from bank_extractors.bapro_pdf_extractor import _extractor

        text = "Prox.Vto. 15/03\nProx.Cierre 10/03"
        result = _extractor._extract_fecha_vencimiento(text, year=2026)
        assert result == "2026-03-15"

    def test_extract_fecha_vencimiento_vencimiento_dd_mon_yy(self):
        """VENCIMIENTO 07 Jul 25 → 2025-07-07 (formato BAPRO real)."""
        from bank_extractors.bapro_pdf_extractor import _extractor

        text = "VENCIMIENTO 07 Jul 25\n25 Junio 02 080069 * RAPPI 5.499,00"
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-07-07"


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

    def test_extract_fecha_vencimiento_from_text(self):
        """_extract_fecha_vencimiento retorna YYYY-MM-DD cuando hay Vencimiento : DD/MM/YY."""
        from bank_extractors.amex_pdf_extractor import _extractor

        text = "Vencimiento : 27/11/25\nEstado de Cuenta\n..."
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-11-27"

    def test_extract_fecha_vencimiento_ignores_detalle_mes_anterior(self):
        """No toma el vencimiento del ciclo anterior (Detalle mes anterior)."""
        from bank_extractors.amex_pdf_extractor import _extractor

        text = """Facturación
Vencimiento : 29/01/25
21/01/25 28/01/25
Detalle mes anterior
Vencimiento : 30/12/24
Pago Min. $ : 11.074,69"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-01-29"  # Del encabezado, no 2024-12-30 de Detalle

    def test_extract_fecha_vencimiento_returns_none_when_only_in_detalle_mes_anterior(self):
        """Retorna None si el único Vencimiento : está en Detalle mes anterior."""
        from bank_extractors.amex_pdf_extractor import _extractor

        text = """Estado de Cuenta
21/01/25 28/01/25
Detalle mes anterior
Vencimiento : 30/12/24
Pago Min. $ : 11.074,69"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result is None  # Usar params en ese caso

    def test_extract_fecha_vencimiento_from_table_vencimiento_actual(self):
        """Extrae la 2ª fecha (Vencimiento Actual). Orden: Fact Actual, Vto Actual, Fact Próx, Vto Próx."""
        from bank_extractors.amex_pdf_extractor import _extractor

        text = """Facturación
Vencimiento
Actual
Próxima
FEDERICO GOSMAN 3766-367019-32003
21/01/25
28/01/25
1.037.637,34
Detalle mes anterior
Vencimiento : 30/12/24
18/02/25
25/02/25
Fecha y detalle de las transacciones"""
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-01-28"  # Vencimiento Actual (2ª fecha)

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

    def test_skips_acreditacion_de_pago_ocr_corruption(self):
        """Líneas de acreditación de pago (OCR corrupto) no deben parsearse como gastos."""
        text = """________________________________________________________________________
15 de Enero 50.000,00
AACREDIBTACIOCN DE VDUESTREO PAGFO G ProHcesadoI el 26/12/2024 L M NCR
REFERENCIA 12345
________________________________________________________________________
20 de Enero 1.500,00
MERCADOPAGO *COMERCIO REAL
REFERENCIA 67890
________________________________________________________________________"""
        rows = _parse_amex(text, billing_period=(1, 2025))
        assert len(rows) == 1
        assert "MERCADOPAGO" in rows[0]["detalles"]
        assert not any(
            "AACREDIBTACIOCN" in str(r.get("detalles", "")) for r in rows
        )


class TestBaproMcPdfExtractor:
    """BAPRO MasterCard PDF extractor: DD-Mon-YY + cupon + monto."""

    def test_get_extractor_bapro_pdf_mastercard_returns_callable(self):
        fn = get_extractor("bapro_pdf_mastercard")
        assert callable(fn)

    def test_extract_bapro_pdf_mastercard_returns_dataframe_with_required_columns(self):
        extract = get_extractor("bapro_pdf_mastercard")
        df = extract(b"")
        assert isinstance(df, pd.DataFrame)
        for col in ["fecha_transaccion", "monto", "detalles"]:
            assert col in df.columns, f"missing column {col}"

    def test_parse_compra_usd_marks_dolares(self):
        text = """DETALLE DEL MES
FECHA NRO CUPON PESOS DOLARES
COMPRAS DEL MES
23-Ago-25 NETFLIX.COM (USA,ARS, 15999,00) 00090 12,10
TOTAL TITULAR GOSMAN FEDERICO HORA 377354,73 12,10"""
        rows = _parse_bapro_mc(text)
        assert len(rows) == 1
        assert rows[0]["fecha_transaccion"] == "23-Aug-25"
        assert rows[0]["numero_operacion"] == "00090"
        assert rows[0]["moneda"] == "dolares"
        assert rows[0]["monto"] == 12.10

    def test_parse_compra_pesos_marks_pesos(self):
        text = """DETALLE DEL MES
FECHA NRO CUPON PESOS DOLARES
COMPRAS DEL MES
26-Ago-25 PRIME VIDEO 00753 7993,77
TOTAL TITULAR GOSMAN FEDERICO HORA 377354,73 12,10"""
        rows = _parse_bapro_mc(text)
        assert len(rows) == 1
        assert rows[0]["numero_operacion"] == "00753"
        assert rows[0]["moneda"] == "pesos"
        assert rows[0]["monto"] == 7993.77

    def test_parse_cuotas_extracts_en_cuotas(self):
        text = """DETALLE DEL MES
FECHA NRO CUPON PESOS DOLARES
CUOTAS DEL MES
30-Nov-24 KAMADO B10 09/12 06874 277251,33
TOTAL TITULAR GOSMAN FEDERICO HORA 377354,73 12,10"""
        rows = _parse_bapro_mc(text)
        assert len(rows) == 1
        assert rows[0]["en_cuotas"] is True
        assert rows[0]["descripcion_cuota"] == "09/12"

    def test_debitos_automaticos_09_25_does_not_mark_cuotas(self):
        text = """DETALLE DEL MES
FECHA NRO CUPON PESOS DOLARES
DEBITOS AUTOMATICOS
19-Ago-25 AYSASADA01006217 09/25 04417 19119,63
TOTAL TITULAR GOSMAN FEDERICO HORA 377354,73 12,10"""
        rows = _parse_bapro_mc(text)
        assert len(rows) == 1
        assert rows[0]["en_cuotas"] is False
        assert rows[0]["descripcion_cuota"] is None

    def test_extract_fecha_vencimiento_v_encimiento_actual(self):
        from bank_extractors.bapro_mc_pdf_extractor import _extractor

        text = "V encimiento actual: 08-Sep-25 Pago Mínimo: $ 105300,00"
        result = _extractor._extract_fecha_vencimiento(text)
        assert result == "2025-09-08"


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
        assert "fecha_vencimiento" in df.columns
        assert df["fecha_vencimiento"].notna().any(), "AMEX sample debería traer fecha_vencimiento"


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
            if "fecha_vencimiento" in df.columns and df["fecha_vencimiento"].notna().any():
                assert len(df[df["fecha_vencimiento"].notna()]) > 0


@pytest.mark.regression
class TestBaproMcPdfRegression:
    """Regresión: extractor BAPRO MasterCard sobre PDFs reales."""

    def test_bapro_mc_sample_returns_valid_dataframe(self):
        import os

        base = os.path.join(os.path.dirname(__file__), "..", "samples", "bapro_mc")
        files = [f for f in os.listdir(base) if f.endswith(".pdf")] if os.path.isdir(base) else []
        if not files:
            pytest.skip("samples/bapro_mc/ no disponible")
        path = os.path.join(base, sorted(files)[0])

        with open(path, "rb") as f:
            content = f.read()
        extract = get_extractor("bapro_pdf_mastercard")
        df = extract(content)
        assert isinstance(df, pd.DataFrame)
        assert "fecha_transaccion" in df.columns
        assert "monto" in df.columns
        assert "detalles" in df.columns
        assert "red" in df.columns
        assert "fecha_vencimiento" in df.columns
        if len(df) > 0:
            assert (df["monto"] > 0).all()
            assert pd.api.types.is_datetime64_any_dtype(df["fecha_transaccion"])
            assert df["red"].iloc[0] == "Mastercard"
            assert df["fecha_vencimiento"].notna().any()


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
            if "fecha_vencimiento" in df.columns and df["fecha_vencimiento"].notna().any():
                assert len(df[df["fecha_vencimiento"].notna()]) > 0
