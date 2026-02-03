"""Tests para la estructura del payload file_results enviado por send_feedback."""


def test_file_result_payload_structure():
    """El payload de file_results debe incluir extractor, transactions_count y message."""
    payload = {
        "source_file_id": 1,
        "status": "completed",
        "error": None,
        "extractor": "bbva_pdf_visa",
        "transactions_count": 42,
        "message": "42 transacciones procesadas",
    }
    assert "extractor" in payload
    assert "transactions_count" in payload
    assert "message" in payload
    assert payload["transactions_count"] == 42
    assert "transacciones" in payload["message"]


def test_file_result_payload_empty_dataframe():
    """Payload cuando el extractor devuelve DataFrame vacío."""
    payload = {
        "source_file_id": 2,
        "status": "completed",
        "error": None,
        "extractor": "amex_pdf",
        "transactions_count": 0,
        "message": "Archivo vacío, 0 transacciones extraídas",
    }
    assert payload["transactions_count"] == 0
    assert "Archivo vacío" in payload["message"]


def test_file_result_payload_failed():
    """Payload cuando falla el procesamiento."""
    payload = {
        "source_file_id": 3,
        "status": "failed",
        "error": "Extractor no encontrado",
        "extractor": "unknown",
        "transactions_count": None,
        "message": None,
    }
    assert payload["status"] == "failed"
    assert payload["transactions_count"] is None
