import pandas as pd
from kafka import KafkaProducer
import json
import hashlib
from utils.data_standardizer import generate_event_id
# Importamos los extractores específicos
from bank_extractors import get_extractor, list_extractors

# Definimos un mapeo simple (Patrón de Fábrica)
EXTRACTORS = {
    'banco_a': extract_bank_a,
    'banco_b': extract_bank_b,
}

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

def ingest_file(bank_name: str, file_path: str):
    try:
        extractor_func = get_extractor(bank_name)
    except ValueError as e:
        print(f"Error al obtener extractor: {e}. Extractores disponibles: {list_extractors()}")
        return
    
    df = extractor_func(file_path)
    
    # Aplicamos la lógica de secuencia e ID único
    df['secuencia'] = df.groupby(['fecha', 'monto', 'comercio']).cumcount()
    df['event_id'] = df.apply(generate_event_id, axis=1)

    for _, row in df.iterrows():
        producer.send('transacciones_raw', key=row['event_id'].encode(), value=row.to_dict())
    
    producer.flush()
    print(f"Ingesta de '{bank_name}' completada para {len(df)} registros.")

if __name__ == "__main__":
    # Ejemplo de uso: 
    # Suponiendo que tienes un archivo "banco_a_gastos.xlsx" en la carpeta ingestion
    ingest_file('banco_a', 'banco_a_gastos.xlsx')
    # O para el otro banco:
    # ingest_file('banco_b', 'otro_banco.xlsx')