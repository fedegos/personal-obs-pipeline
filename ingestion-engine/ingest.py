import hashlib
import json

import pandas as pd
from kafka import KafkaProducer


def generate_event_id(row):
    # Concatenamos datos para un ID determinista
    string_base = f"{row['fecha']}{row['monto']}{row['comercio']}{row['secuencia']}"
    return hashlib.sha256(string_base.encode()).hexdigest()

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v).encode('utf-8')
)

def process():
    df = pd.read_excel("datos_banco.xlsx")
    # Generar secuencia para compras idénticas el mismo día
    df['secuencia'] = df.groupby(['fecha', 'monto', 'comercio']).cumcount()

    for _, row in df.iterrows():
        payload = row.to_dict()
        payload['event_id'] = generate_event_id(row)
        # Enviamos al topic RAW
        producer.send('transacciones_raw', key=payload['event_id'].encode(), value=payload)

    producer.flush()
    print("Datos enviados a Kafka topic: transacciones_raw")

if __name__ == "__main__":
    process()
