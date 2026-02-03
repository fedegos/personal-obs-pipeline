# Extractores PDF

Base común para extraer transacciones de resúmenes de tarjetas en PDF.

## Arquitectura

- **PdfExtractorBase**: clase abstracta con Template Method. Gestiona lectura de bytes, extracción de texto (pdfplumber), validaciones y armado del DataFrame.
- **utils**: helpers compartidos (normalizar montos, meses, cuotas, fechas).
- **Parsers**: cada banco implementa `_parse_transactions(text, **kwargs)` que retorna `list[dict]`.

## Agregar un nuevo extractor

1. Crear `banco_x_pdf_extractor.py` en `bank_extractors/`.
2. Subclasificar `PdfExtractorBase`:

```python
from . import register_extractor
from .pdf.base import PdfExtractorBase
from .pdf.utils import normalize_monto, should_skip_text

class BancoXPdfExtractor(PdfExtractorBase):
    extractor_id = "banco_x_pdf"
    default_network = "Visa"

    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        rows = []
        for line in text.split("\n"):
            # ... parsear línea ...
            rows.append({
                "fecha_transaccion": "...",
                "monto": ...,
                "detalles": "...",
                "moneda": "pesos",
                "numero_operacion": "...",
                "en_cuotas": False,
                "descripcion_cuota": "-",
            })
        return rows

_extractor = BancoXPdfExtractor()

@register_extractor("banco_x_pdf")
def extract_banco_x_pdf(file_content: bytes, **kwargs):
    return _extractor.extract(file_content, **kwargs)
```

3. Importar el módulo en `bank_extractors/__init__.py`.
4. Añadir el banco en `config/initializers/bank_schemas.rb` (Rails) si aplica.

## Utilidades disponibles

| Función | Uso |
|---------|-----|
| `normalize_monto(value)` | Convierte "1.500,50" → 1500.5 |
| `mes_es_to_en(mes, strict)` | "Ene"/"Enero" → "Jan" |
| `normalize_fecha_mes_es(fecha_str)` | Reemplaza meses ES en DD-MMM-YY |
| `extract_cuota_c_xx_yy(detalles)` | Detecta C.01/06 → (True, "01/06") |
| `extract_cuota_amex(detalles)` | Detecta CUOTA 04/06 DE ... |
| `should_skip_text(text, patterns)` | Excluye líneas/bloques no transaccionales |
| `deduce_year(...)` | Deduce año según período de facturación (AMEX) |

## Tests

- Tests unitarios con texto simulado en `tests/test_extractors_pdf.py`.
- Tests de regresión (`@pytest.mark.regression`) con PDFs reales en `samples/`.
  Se omiten automáticamente si `samples/` no existe (p. ej. en CI sin muestras).
