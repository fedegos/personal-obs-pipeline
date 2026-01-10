# Asumimos que el Banco A usa columnas: 'Date', 'Amount', 'Description'
import pandas as pd
import numpy as np

from utils.data_standardizer import apply_standard_format
from . import register_extractor # Importación relativa directa al __init__

@register_extractor('visa')
def extract_visa(file_path: str) -> pd.DataFrame:
    df = pd.read_csv(file_path, sep=";", thousands=",", decimal=".", parse_dates=['Fecha Origen'], date_format='%d/%m/%Y')
    
    # Lógica de transformación específica VISA: renombrar columnas

    df["red"] = "Visa"
    df["en_cuotas"] = df["Establecimiento"].str.contains(r'\d{2}/\d{2}$', regex=True)
    # df["Importe"] = pd.to_numeric(df['Importe'])
    df['descripcion_cuota'] = np.where(df['en_cuotas'], df['Establecimiento'].str[-5:], "-")

    # ['Numero Tarjeta', 'Fecha Origen', 'Establecimiento', 'Numero Comprobante', 'Moneda', 'Importe']
    df = df.rename(columns={
        'Numero Tarjeta': 'numero_tarjeta',
        'Fecha Origen': 'fecha_transaccion',
        'Establecimiento': 'detalles',
        'Numero Comprobante': 'numero_operacion',   
        'Moneda': 'moneda',
        'Importe': 'monto'
    })
    
    return apply_standard_format(df)