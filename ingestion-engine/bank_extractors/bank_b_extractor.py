# Asumimos que el Banco B usa columnas: 'Fecha Operacion', 'Importe', 'Detalle'
import pandas as pd
from utils.data_standardizer import apply_standard_format
from .__init__ import register_extractor

@register_extractor('banco_b')
def extract_bank_b(file_path: str) -> pd.DataFrame:
    df = pd.read_excel(file_path, header=2) # El Banco B tiene 2 filas de cabecera extra
    # Lógica de transformación específica: renombrar columnas
    df = df.rename(columns={
        'Fecha Operacion': 'fecha',
        'Importe': 'monto',
        'Detalle': 'comercio'
    })
    # Invertir el monto si viene en positivo/negativo y debe ser solo positivo
    df['monto'] = df['monto'].abs() 

    return apply_standard_format(df)