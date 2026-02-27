"""
Extractor para resúmenes de tarjetas BBVA Mastercard en formato PDF.
Reutiliza la lógica de BBVA Visa ya que el formato es idéntico.
"""

import pandas as pd

from . import register_extractor
from .bbva_pdf_extractor import BbvaPdfExtractor


class BbvaMcPdfExtractor(BbvaPdfExtractor):
    extractor_id = "bbva_pdf_mastercard"
    default_network = "Mastercard"


_extractor = BbvaMcPdfExtractor()


@register_extractor("bbva_pdf_mastercard")
def extract_bbva_pdf_mastercard(file_content: bytes, **kwargs) -> pd.DataFrame:
    """Extrae movimientos de resumen BBVA Mastercard en PDF."""
    return _extractor.extract(file_content, **kwargs)
