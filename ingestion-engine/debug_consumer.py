import json

from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'transacciones_raw',
    bootstrap_servers='localhost:9092',
    auto_offset_reset='earliest', # Leer desde el principio
    group_id='debug-group',
    value_deserializer=lambda x: json.loads(x.decode('utf-8'))
)

print("Waiting for events...")
for message in consumer:
    print(f"ID: {message.key.decode()}")
    print(f"Data: {json.dumps(message.value, indent=2, ensure_ascii=False)}")
    print("-" * 20)
