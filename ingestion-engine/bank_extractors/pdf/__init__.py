"""
Módulo base para extractores de PDF de resúmenes de tarjetas.

- PdfExtractorBase: clase base con Template Method (validación, lectura, armado).
- utils: helpers compartidos (normalizar montos, meses, cuotas).
"""

from . import utils
from .base import REQUIRED_COLUMNS, PdfExtractorBase

__all__ = ["PdfExtractorBase", "REQUIRED_COLUMNS", "utils"]
