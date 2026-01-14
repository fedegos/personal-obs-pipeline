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

def fetch_gsheet_data(spreadsheet_id: str, sheet_name: str):
    """Acceso a Google Sheets por ID y nombre de pestaña dinámico."""
    # El archivo credentials.json debe estar en la raíz del contenedor del worker
    gc = gspread.service_account(filename='credentials.json')
    sh = gc.open(spreadsheet_id)
    
    # En 2026, usamos el nombre de pestaña enviado desde la UI de Rails
    try:
        worksheet = sh.worksheet(sheet_name)
    except gspread.exceptions.WorksheetNotFound:
        raise ValueError(f"La pestaña '{sheet_name}' no existe en el documento.")
    
    all_values = worksheet.get_all_values()
    if not all_values:
        return pd.DataFrame(), worksheet.title
        
    headers = all_values[0] # Usamos la primera fila como headers (ajusta si es necesario)
    data = all_values[3:]   # Salteamos filas según tu lógica actual
    
    return pd.DataFrame(data, columns=headers), worksheet.title

# --- Transformación Principal ---

@register_extractor('amex')
def extract_amex(file_content=None, **kwargs) -> pd.DataFrame:
    """
    Extractor AMEX adaptado para 2026.
    file_content: Será None para AMEX (viene de Google Sheets).
    kwargs: Contiene 'spreadsheet_id', 'year', 'notes', etc., desde Rails.
    """
    # 1. Extraer parámetros capturados en Rails
    # Si no viene el ID, lanzamos error para que Rails reciba el feedback 'failed'
    spreadsheet_id = kwargs.get('spreadsheet_id')
    target_sheet = kwargs.get('sheet') # <--- Captura el nombre de la pestaña


    if not spreadsheet_id:
        raise ValueError("Falta el parámetro obligatorio 'spreadsheet_id' para AMEX.")
    
    try:
        # 2. Obtención mediante ID de documento
        df, sheet_title = fetch_gsheet_data(spreadsheet_id, target_sheet)

        # 3. Pipeline de Transformación
        df = (
            df.assign(
                red="AMEX",
                # Podrías usar fiscal_year aquí si la fecha del sheet no tiene año completo
                fecha_transaccion=lambda x: pd.to_datetime(x['Fecha'], format='%d-%m-%Y', errors='coerce'),
                numero_tarjeta=f"XXXXXXXXXX {sheet_title}",
                
                # Lógica de cuotas
                en_cuotas=lambda x: x['Descripción'].str.contains(r'CUOTA \d{2}/\d{2}$', regex=True),
                descripcion_cuota=lambda x: np.where(
                    x['en_cuotas'], 
                    x['Descripción'].str.extract(r'(?<=CUOTA )(\d{2}/\d{2})', expand=False), 
                    "-"
                ),
                
                # Limpieza numérica
                cargos_p=lambda x: limpiar_moneda(x['Cargos en Pesos']),
                cargos_d=lambda x: limpiar_moneda(x['Cargos en Dólares'])
            )
            .assign(
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

        # ... (resto de la limpieza de columnas y filtrado igual) ...
        
        columnas_finales = [
            'fecha_transaccion', 'detalles', 'monto', 'moneda', 
            'red', 'numero_tarjeta', 'en_cuotas', 'descripcion_cuota'
        ]
        df = df[columnas_finales].copy()
        df = df[df['monto'] > 0].dropna(subset=['monto'])
        df['numero_operacion'] = df.groupby(['fecha_transaccion', 'detalles', 'monto']).cumcount()

        return apply_standard_format(df)

    except Exception as e:
        # Este print aparecerá en los logs del contenedor python_worker
        print(f"\n❌ ERROR en extract_amex (ID: '{spreadsheet_id}'):")
        traceback.print_exc()
        raise e # Re-lanzamos para que main.py envíe el feedback 'failed' a Rails

