"""Unit tests for utils.data_standardizer (pure functions, no I/O)."""
import pandas as pd

from utils.data_standardizer import apply_standard_format, generate_event_id


class TestGenerateEventId:
    """Tests for generate_event_id."""

    def test_deterministic_same_input_same_hash(self):
        row = pd.Series({
            "fecha_transaccion": "2025-01-15",
            "monto": 100.5,
            "detalles": "SUPER",
            "numero_operacion": 0,
        })
        a = generate_event_id(row)
        b = generate_event_id(row)
        assert a == b
        assert len(a) == 64
        assert all(c in "0123456789abcdef" for c in a)

    def test_different_input_different_hash(self):
        row1 = pd.Series({
            "fecha_transaccion": "2025-01-15",
            "monto": 100.5,
            "detalles": "SUPER",
            "numero_operacion": 0,
        })
        row2 = pd.Series({
            "fecha_transaccion": "2025-01-15",
            "monto": 100.5,
            "detalles": "OTRO",
            "numero_operacion": 0,
        })
        assert generate_event_id(row1) != generate_event_id(row2)


class TestApplyStandardFormat:
    """Tests for apply_standard_format."""

    def test_converts_fecha_to_datetime(self):
        df = pd.DataFrame({
            "fecha_transaccion": ["2025-01-15", "2025-01-16"],
            "monto": [10.0, 20.0],
            "detalles": ["A", "B"],
        })
        out = apply_standard_format(df)
        assert pd.api.types.is_datetime64_any_dtype(out["fecha_transaccion"])

    def test_converts_monto_to_numeric(self):
        df = pd.DataFrame({
            "fecha_transaccion": ["2025-01-15"],
            "monto": ["42.5"],
            "detalles": ["X"],
        })
        out = apply_standard_format(df)
        assert pd.api.types.is_numeric_dtype(out["monto"])
        assert out["monto"].iloc[0] == 42.5

    def test_strips_detalles(self):
        df = pd.DataFrame({
            "fecha_transaccion": ["2025-01-15"],
            "monto": [1.0],
            "detalles": ["  texto  "],
        })
        out = apply_standard_format(df)
        assert out["detalles"].iloc[0] == "texto"

    def test_returns_same_df_reference(self):
        df = pd.DataFrame({
            "fecha_transaccion": ["2025-01-15"],
            "monto": [1.0],
            "detalles": ["x"],
        })
        out = apply_standard_format(df)
        assert out is df
