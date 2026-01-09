# Asumimos que el Banco A usa columnas: 'Date', 'Amount', 'Description'
import pandas as pd
from utils.data_standardizer import apply_standard_format
from .__init__ import register_extractor

@register_extractor('banco_a')
def extract_bank_a(file_path: str) -> pd.DataFrame:
    df = pd.read_excel(file_path)
    # Lógica de transformación específica: renombrar columnas
    df = df.rename(columns={
        'Date': 'fecha',
        'Amount': 'monto',
        'Description': 'comercio'
    })
    # Eliminar filas innecesarias si existen...
    
    return apply_standard_format(df)