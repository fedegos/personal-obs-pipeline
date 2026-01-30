import io

import numpy as np
import pandas as pd

from utils.data_standardizer import apply_standard_format

from . import register_extractor


@register_extractor('visa')
def extract_visa(file_content: bytes, **kwargs) -> pd.DataFrame:
    """
    Extractor para consumos de Visa desde archivos CSV (resumen descargado).
    Espera formato con separador ';' y fechas 'dd/mm/YYYY'.
    """
    try:
        # 1. Carga inicial
        # Nota: Cargamos 'Importe' como string si sospechamos que puede traer formatos mixtos,
        # o directamente como float si el CSV es estándar.
        df_raw = pd.read_csv(
            io.BytesIO(file_content),
            sep=";",
            thousands=",",
            decimal=".",
            parse_dates=['Fecha Origen'],
            date_format='%d/%m/%Y'
        )

        # 2. Pipeline de Transformación
        df = (
            df_raw.assign(
                red="Visa",
                # Detectar cuotas al final del texto (ej: "ESTABLECIMIENTO 02/06")
                en_cuotas=lambda x: x['Establecimiento'].str.contains(r'\d{2}/\d{2}$', regex=True),

                # Extraer la cuota (últimos 5 caracteres) solo si en_cuotas es True
                descripcion_cuota=lambda x: np.where(
                    x['en_cuotas'],
                    x['Establecimiento'].str[-5:],
                    "-"
                ),

                # Normalización de Moneda (ej: de '$' o 'ARS' a 'pesos')
                moneda=lambda x: x['Moneda'].str.lower().replace({
                    '$': 'pesos',
                    'ars': 'pesos',
                    'usd': 'dólares',
                    'u$s': 'dólares'
                }),

                # Asegurar que el monto sea numérico
                monto=lambda x: pd.to_numeric(x['Importe'], errors='coerce')
            )
            .rename(columns={
                'Numero Tarjeta': 'numero_tarjeta',
                'Fecha Origen': 'fecha_transaccion',
                'Establecimiento': 'detalles',
                'Numero Comprobante': 'numero_operacion'
            })
        )

        # 3. Limpieza y Selección Final
        columnas_finales = [
            'fecha_transaccion', 'detalles', 'monto', 'moneda',
            'red', 'numero_tarjeta', 'en_cuotas', 'descripcion_cuota', 'numero_operacion'
        ]

        # Filtrar filas sin monto o con monto cero y seleccionar columnas
        df = df[df['monto'] > 0][columnas_finales].copy()

        return apply_standard_format(df)

    except Exception as e:
        print("❌ Error procesando archivo Visa.")
        raise e
