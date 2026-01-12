from bank_extractors import get_extractor, list_extractors
from utils.data_standardizer import generate_event_id
import pandas as pd

import traceback

from utils.s3_client import get_s3_client


def test_extraction(bank_name, file_path, **kwargs):

    s3 = get_s3_client()
    bucket_name = kwargs.get('bucket_name') 

    print(f"--- Probando Extractor: {bank_name} ---")
    try:

        # 1. Descargar archivo de LocalStack S3
        print(f"📥 Descargando {file_path} desde S3...")
        response = s3.get_object(Bucket=bucket_name, Key=file_path)        
        file_content = response['Body'].read()
        
        # 1. Obtener extractor
        extractor_func = get_extractor(bank_name)
        
        # 2. Ejecutar extracción
        df = extractor_func(file_content, **kwargs)
        
        # 3. Aplicar lógica de secuencia e ID (Copia de main.py)
        # df['secuencia'] = df.groupby(['fecha_transaccion', 'monto', 'detalles']).cumcount()
        df['event_id'] = df.apply(generate_event_id, axis=1)
        
        # 4. Mostrar resultados
        print(f"\n✅ Éxito: Se procesaron {len(df)} registros.")

        for _, row in df.iterrows():
            print(f"Evento enviado: ${row.to_dict()}")
            
    except Exception as e:
        print("\n❌ ERROR DETALLADO:")
        # Esto imprimirá la secuencia de comandos que falló
        traceback.print_exc() 

if __name__ == "__main__":
    print(f"Extractores registrados: {list_extractors()}")
    # Ajusta la ruta al archivo que creaste
    # test_extraction('visa', '../data/input/Movimientos_bbva.csv')
    # test_extraction('visa', '../data/input/Movimientos_bapro.csv')
    # test_extraction('amex', 'AMEX')
    
    test_extraction(
        "bbva",
        'raw/Últimos movimientos.xlsx', 
        bucket_name='bank-ingestion',
        card_number="XXXX XXXX XXX 3640",
        card_network="MC")