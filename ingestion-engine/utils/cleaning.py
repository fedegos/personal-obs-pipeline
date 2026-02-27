"""Utilidades de limpieza de datos compartidas entre extractores."""

import pandas as pd


def limpiar_moneda(columna: pd.Series, **kwargs) -> pd.Series:
    """Convierte strings de moneda (ej: '$6.446,30') a float64."""
    return (
        columna.astype(str)
        .str.replace(r"[^\d,.-]", "", regex=True)
        .str.replace(".", "", regex=False)
        .str.replace(",", ".", regex=False)
        .pipe(pd.to_numeric, errors="coerce")
    )
