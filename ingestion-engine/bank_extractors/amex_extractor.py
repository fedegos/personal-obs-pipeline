import pandas as pd
import numpy as np
import gspread
import traceback
from . import register_extractor
from utils.data_standardizer import apply_standard_format

# --- Utilidades de Limpieza ---

def limpiar_moneda(columna: pd.Series, **kwargs) -> pd.Series:
    """Convierte strings de moneda (ej: '$6.446,30') a float64."""
    return (
        columna.astype(str)
        .str.replace(r'[^\d,.-]', '', regex=True)
        .str.replace('.', '', regex=False)
        .str.replace(',', '.', regex=False)
        .pipe(pd.to_numeric, errors='coerce')
    )

# --- Lógica de Extracción ---

def fetch_gsheet_data(sheet_name: str):
    """Encapsula la comunicación con Google Sheets."""
    gc = gspread.service_account(filename='credentials.json')
    sh = gc.open(sheet_name)
    worksheet = sh.get_worksheet(0)
    
    all_values = worksheet.get_all_values()
    headers = all_values[0]
    data = all_values[3:] # Salteamos filas vacías/metadatos iniciales
    
    return pd.DataFrame(data, columns=headers), worksheet.title

# --- Transformación Principal ---

@register_extractor('amex')
def extract_amex(sheet_name: str) -> pd.DataFrame:
    try:
        # 1. Obtención
        df, sheet_title = fetch_gsheet_data(sheet_name)

        # 2. Pipeline de Transformación (Legibilidad mejorada)
        df = (
            df.assign(
                red="AMEX",
                fecha_transaccion=lambda x: pd.to_datetime(x['Fecha'], format='%d-%m-%Y', errors='coerce'),
                numero_tarjeta=f"XXXXXXXXXX {sheet_title}",
                
                # Lógica de cuotas
                en_cuotas=lambda x: x['Descripción'].str.contains(r'CUOTA \d{2}/\d{2}$', regex=True),
                descripcion_cuota=lambda x: np.where(
                    x['en_cuotas'], 
                    x['Descripción'].str.extract(r'(?<=CUOTA )(\d{2}/\d{2})', expand=False), 
                    "-"
                ),
                
                # Limpieza numérica preliminar
                cargos_p=lambda x: limpiar_moneda(x['Cargos en Pesos']),
                cargos_d=lambda x: limpiar_moneda(x['Cargos en Dólares'])
            )
            .assign(
                # Lógica de selección de moneda y monto
                moneda=lambda x: np.select(
                    [x['cargos_p'] > 0, x['cargos_d'] > 0], 
                    ['pesos', 'dólares'], 
                    default='-'
                ),
                monto=lambda x: np.select(
                    [x['cargos_p'] > 0, x['cargos_d'] > 0], 
                    [x['cargos_p'], x['cargos_d']], 
                    default=0.0
                )
            )
            .rename(columns={'Descripción': 'detalles'})
        )

        # 3. Limpieza de columnas y filas
        columnas_finales = [
            'fecha_transaccion', 'detalles', 'monto', 'moneda', 
            'red', 'numero_tarjeta', 'en_cuotas', 'descripcion_cuota'
        ]
        
        df = df[columnas_finales].copy()
        
        # Filtrar montos inválidos o cero
        df = df[df['monto'] > 0].dropna(subset=['monto'])

        # 4. Generar ID único por duplicados (cumcount)
        df['numero_operacion'] = df.groupby(['fecha_transaccion', 'detalles', 'monto']).cumcount()

        return apply_standard_format(df)

    except Exception as e:
        print(f"\n❌ ERROR en extract_amex ('{sheet_name}'):")
        traceback.print_exc()
        raise
