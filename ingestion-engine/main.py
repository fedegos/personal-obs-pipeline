import pandas as pd
from kafka import KafkaProducer
import json
import hashlib

from utils.data_standardizer import generate_event_id
from bank_extractors import get_extractor, list_extractors
from utils.s3_client import get_s3_client

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v, default=json_serial).encode('utf-8')
)

# Función para manejar objetos que JSON no reconoce por defecto
def json_serial(obj):
    if isinstance(obj, (pd.Timestamp, pd.DatetimeIndex)):
        return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

def ingest_from_s3(bank_name: str, bucket_name: str, s3_key: str):
    s3 = get_s3_client()
    
    try:
        # 1. Descargar archivo de LocalStack S3
        print(f"📥 Descargando {s3_key} desde S3...")
        response = s3.get_object(Bucket=bucket_name, Key=s3_key)
        file_content = response['Body'].read()
                
        # 2. Obtener el extractor y procesar
        extractor_func = get_extractor(bank_name)
        df = extractor_func(file_content)
        
        # 3. Publicar en Kafka (tu lógica actual de producer.send)
        # ...
        print(f"✅ Ingesta de '{bank_name}' completada para {len(df)} registros.")
        
    except Exception as e:
        print(f"❌ Error en la ingesta: {e}")



def ingest_file(bank_name: str, file_path: str):
    try:
        extractor_func = get_extractor(bank_name)
    except ValueError as e:
        print(f"Error al obtener extractor: {e}. Extractores disponibles: {list_extractors()}")
        return
    
    df = extractor_func(file_path)
    
    # Aplicamos la lógica de secuencia e ID único
    df['event_id'] = df.apply(generate_event_id, axis=1)

    for _, row in df.iterrows():
        producer.send('transacciones_raw', key=row['event_id'].encode(), value=row.to_dict())
    
    producer.flush()
    print(f"Ingesta de '{bank_name}' completada para {len(df)} registros.")

if __name__ == "__main__":
    # Ejemplo de uso: 

    # ingest_file('visa', '../data/input/Movimientos_bbva.csv')
    # ingest_file('visa', '../data/input/Movimientos_bapro.csv')

    ingest_from_s3('visa', 'bank-ingestion', 'raw/Movimientos_bbva.csv')
    ingest_from_s3('visa', 'bank-ingestion', 'raw/Movimientos_bapro.csv')

    ingest_file('amex', 'AMEX')