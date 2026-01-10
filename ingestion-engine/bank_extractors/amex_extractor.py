# Asumimos que el Banco A usa columnas: 'Date', 'Amount', 'Description'
import pandas as pd
import numpy as np

import re

import gspread
from oauth2client.service_account import ServiceAccountCredentials

from utils.data_standardizer import apply_standard_format
from . import register_extractor # Importación relativa directa al __init__

@register_extractor('amex')
def extract_amex(sheet_name: str) -> pd.DataFrame:

    try:
        '''
        # 1. Configurar Credenciales
        scope = ["spreadsheets.google.com", "www.googleapis.com"]
        creds = ServiceAccountCredentials.from_json_keyfile_name('../credentials.json', scope)
        client = gspread.authorize(creds)

        # 2. Abrir la hoja y obtener datos
        sheet = client.open(sheet_name).sheet1
        
        # Obtener todas las filas como una lista de listas
        '''
        # Forma moderna de autenticar (más robusta en 2026)
        gc = gspread.service_account(filename='credentials.json')
        
        # Abrir por nombre
        sh = gc.open(sheet_name)
        worksheet = sh.get_worksheet(0) # Abrir la primera pestaña
    
        all_values = worksheet.get_all_values() 

        # Filtrar filas: 
        # all_values[0] es el encabezado (fila 1)
        # all_values[3:] son los datos desde la fila 4 en adelante (salteando 2 y 3)
        headers = all_values[0]
        data_rows = all_values[3:] 

        # Crear el DataFrame
        df = pd.DataFrame(data_rows, columns=headers)    # Lógica de transformación específica AMEX: renombrar columnas

        '''
        ['Fecha', 'Descripción', 'Pagos en Pesos', 'Cargos en Pesos',
        'Pagos en Dólares', 'Cargos en Dólares']
        '''

        df["red"] = "AMEX"
        df['Fecha'] = pd.to_datetime(df['Fecha'], format='%d-%m-%Y')

        df["numero_tarjeta"] = f"XXXXXXXX {worksheet.title}"
        df["en_cuotas"] = df["Descripción"].str.contains(r'CUOTA \d{2}/\d{2}$', regex=True)

        df["descripcion_cuota"] = np.where(
            df['en_cuotas'], df['Descripción'].str.extract(r'(?<=CUOTA )(\d{2}/\d{2})', expand=False),
            "-"
            )
        
        df["Cargos en Pesos"] = limpiar_moneda(df['Cargos en Pesos'])
        df["Cargos en Dólares"] = limpiar_moneda(df['Cargos en Dólares'])

        condiciones = [
            df['Cargos en Pesos'] > 0,
            df['Cargos en Dólares'] > 0
        ]

        # Definir los valores para cada condición
        opciones = ['pesos', 'dólares']

        opciones_monto = [
            df['Cargos en Pesos'], 
            df['Cargos en Dólares']
        ]

        df['moneda'] = np.select(condiciones, opciones, default='-')
        df['monto'] = np.select(condiciones, opciones_monto, default='-')

        df = df.rename(columns={
            'Fecha': 'fecha_transaccion',
            'Descripción': 'detalles'
        })

        '''
        ['Fecha', 'Descripción', 'Pagos en Pesos', 'Cargos en Pesos',
        'Pagos en Dólares', 'Cargos en Dólares']
        '''    
        df = df.drop(columns=['Pagos en Pesos', 'Cargos en Pesos', 'Pagos en Dólares', 'Cargos en Dólares'])

        # 2. Convertir a numérico para asegurar que la comparación funcione
        # (errors='coerce' convertirá lo que no sea número en NaN)
        df['monto'] = pd.to_numeric(df['monto'], errors='coerce')

        # 3. ELIMINAR REGISTROS CON MONTO 0 o VACÍOS
        df = df[df['monto'] != 0]

        columnas_clave = ['fecha_transaccion', 'detalles', 'monto']
        df['numero_operacion'] = df.groupby(columnas_clave).cumcount()

        return apply_standard_format(df)

    except Exception as e:
        print("\n❌ ERROR DETALLADO:")
        # Esto imprimirá la secuencia de comandos que falló
        traceback.print_exc()     
        raise


def limpiar_moneda(columna):
    """
    Convierte strings de moneda (ej: '$6.446,30') a float (6446.30).
    """
    if columna is None:
        return columna
        
    return (
        columna.astype(str)
        .str.replace(r'[^\d,.-]', '', regex=True) # Quita todo menos dígitos, coma, punto y signo menos
        .str.replace('.', '', regex=False)        # Quita el punto de miles
        .str.replace(',', '.', regex=False)        # Cambia la coma decimal por punto
        .pipe(pd.to_numeric, errors='coerce')      # Convierte a número, si falla pone NaN
    )