import io

import pandas as pd

from utils.cleaning import limpiar_moneda
from utils.data_standardizer import apply_standard_format
from utils.logging_config import get_logger

from . import register_extractor

logger = get_logger(__name__)


@register_extractor("bbva")
def extract_bbva(file_content: bytes, **kwargs) -> pd.DataFrame:
    """
    Extractor para consumos de Visa desde archivos CSV (resumen descargado).
    Espera formato con separador ';' y fechas 'dd/mm/YYYY'.
    """
    card_number = kwargs.get("card_number")
    card_network = kwargs.get("card_network")

    try:
        # 1. Carga inicial
        df_raw = pd.read_excel(io.BytesIO(file_content), engine="openpyxl", header=2)

        # 2. Pipeline de Transformación
        df = df_raw.assign(
            red=card_network,
            fecha_transaccion=lambda x: pd.to_datetime(
                x["Fecha y hora"], format="%d/%m/%y", errors="coerce"
            ),
            numero_tarjeta=card_number,
            # Detectar cuotas al final del texto (ej: "ESTABLECIMIENTO 02/06")
            en_cuotas=lambda x: x["Cuota"] != "-",
            # Normalización de Moneda (ej: de '$' o 'ARS' a 'pesos')
            moneda="pesos",
            # Asegurar que el monto sea numérico
            monto=lambda x: limpiar_moneda(x["Monto"]),
        ).rename(columns={"Movimientos": "detalles", "Cuota": "descripcion_cuota"})

        logger.debug("Columnas cargadas: %s", df.columns.tolist())

        # 3. Limpieza de columnas y filas
        columnas_finales = [
            "fecha_transaccion",
            "detalles",
            "monto",
            "moneda",
            "red",
            "numero_tarjeta",
            "en_cuotas",
            "descripcion_cuota",
        ]

        df = df[columnas_finales].copy()

        # Filtrar montos inválidos o cero
        df = df[df["monto"] > 0].dropna(subset=["monto"])

        # 4. Generar ID único por duplicados (cumcount)
        df["numero_operacion"] = df.groupby(["fecha_transaccion", "detalles", "monto"]).cumcount()

        return apply_standard_format(df)

    except Exception as e:
        logger.exception("Error procesando archivo BBVA: %s", e)
        raise
