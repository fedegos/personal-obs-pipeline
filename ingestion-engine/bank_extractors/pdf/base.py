"""
Clase base para extractores PDF con Template Method.

Orquesta: validación, lectura de texto, parseo (subclase), armado de DataFrame.

Cómo extender con un nuevo banco:
1. Crear subclase de PdfExtractorBase.
2. Definir extractor_id y default_network (ej: "banco_x_pdf", "Mastercard").
3. Implementar _parse_transactions(text, **kwargs) -> list[dict].
   Cada dict debe incluir: fecha_transaccion, monto, detalles, moneda, numero_operacion,
   en_cuotas, descripcion_cuota. Opcional: numero_tarjeta, red.
4. Opcional: _postprocess_fecha(str) para normalizar meses español→inglés.
5. Registrar con @register_extractor("banco_x_pdf") delegando a extractor.extract().
6. Aprovechar utils: normalize_monto, mes_es_to_en, extract_cuota_c_xx_yy,
   extract_cuota_amex, should_skip_text, normalize_fecha_mes_es.
"""

import io
import traceback
from abc import ABC, abstractmethod

import pandas as pd
import pdfplumber

from utils.data_standardizer import apply_standard_format

REQUIRED_COLUMNS = [
    "fecha_transaccion",
    "monto",
    "detalles",
    "moneda",
    "red",
    "numero_operacion",
    "numero_tarjeta",
    "en_cuotas",
    "descripcion_cuota",
]

# Límites por defecto
MIN_FILE_BYTES = 100
MIN_TEXT_CHARS = 50


class PdfExtractorBase(ABC):
    """
    Base para extractores PDF. Template Method:
    1. _validate_input
    2. _extract_text
    3. _parse_transactions (abstracto)
    4. _build_dataframe
    """

    extractor_id: str = "pdf"
    default_network: str = "Visa"

    def __init__(self, min_file_bytes: int = MIN_FILE_BYTES, min_text_chars: int = MIN_TEXT_CHARS):
        self.min_file_bytes = min_file_bytes
        self.min_text_chars = min_text_chars

    def _empty_df(self) -> pd.DataFrame:
        return pd.DataFrame(columns=REQUIRED_COLUMNS)

    def _extract_text_from_pdf(self, file_content: bytes) -> str:
        """Extrae texto de todas las páginas del PDF."""
        full_text = []
        with pdfplumber.open(io.BytesIO(file_content)) as pdf:
            for page in pdf.pages:
                t = page.extract_text()
                if t:
                    full_text.append(t)
        return "\n".join(full_text)

    def _build_dataframe(
        self,
        rows: list[dict],
        card_network: str | None = None,
        card_number: str | None = None,
        postprocess_fecha=None,
    ) -> pd.DataFrame:
        """Ensambla DataFrame con columnas requeridas y metadata."""
        if not rows:
            return self._empty_df()
        df = pd.DataFrame(rows)
        for col in REQUIRED_COLUMNS:
            if col not in df.columns:
                df[col] = None
        df["red"] = card_network or self.default_network
        df["numero_tarjeta"] = card_number
        if postprocess_fecha and "fecha_transaccion" in df.columns:
            df["fecha_transaccion"] = df["fecha_transaccion"].apply(postprocess_fecha)
        df = df[[c for c in REQUIRED_COLUMNS]]
        df = df[df["monto"].notna() & (df["monto"] > 0)]
        return df

    @abstractmethod
    def _parse_transactions(self, text: str, **kwargs) -> list[dict]:
        """Implementado por cada extractor. Convierte texto en lista de transacciones."""
        ...

    def extract(self, file_content: bytes, **kwargs) -> pd.DataFrame:
        """
        Método principal. Valida, lee, parsea y devuelve DataFrame estandarizado.
        """
        empty = self._empty_df()
        if not file_content or len(file_content) < self.min_file_bytes:
            print(
                f"⚠️ {self.extractor_id}: archivo vacío o demasiado pequeño "
                f"({len(file_content) if file_content else 0} bytes)"
            )
            return empty

        try:
            text = self._extract_text_from_pdf(file_content)
            if not text or len(text.strip()) < self.min_text_chars:
                print(
                    f"⚠️ {self.extractor_id}: no se pudo extraer texto del PDF "
                    f"({len(text) if text else 0} caracteres)."
                )
                return empty

            rows = self._parse_transactions(text, **kwargs)
            if not rows:
                sample = text[:500].replace("\n", " ")
                print(
                    f"⚠️ {self.extractor_id}: 0 transacciones encontradas. "
                    f"Muestra: {sample[:200]}..."
                )
                return empty

            df = self._build_dataframe(
                rows,
                card_network=kwargs.get("card_network"),
                card_number=kwargs.get("card_number"),
                postprocess_fecha=getattr(self, "_postprocess_fecha", None),
            )
            if df.empty:
                print(f"⚠️ {self.extractor_id}: todas las filas filtradas (monto=0 o NaN)")
                return empty
            return apply_standard_format(df)
        except Exception as e:
            print(f"❌ {self.extractor_id} error: {e}")
            traceback.print_exc()
            return empty
