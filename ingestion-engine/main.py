import json
import os

import pandas as pd
from confluent_kafka import Consumer, Producer

from bank_extractors import get_extractor, list_extractors
from utils.data_standardizer import generate_event_id
from utils.s3_client import get_s3_client

# Configuración del Productor (para enviar transacciones a Kafka)
producer_conf = {"bootstrap.servers": os.getenv("KAFKA_SERVERS", "redpanda:29092")}
producer = Producer(producer_conf)


def json_serial(obj):
    if isinstance(obj, (pd.Timestamp, pd.DatetimeIndex)):
        return obj.isoformat()
    return str(obj)


def send_feedback(
    source_file_id,
    status,
    error=None,
    extractor=None,
    transactions_count=None,
    message=None,
):
    """Notifica a Rails el resultado del procesamiento."""
    payload = {
        "source_file_id": source_file_id,
        "status": "completed" if status == "success" else "failed",
        "error": error,
        "extractor": extractor,
        "transactions_count": transactions_count,
        "message": message,
    }
    producer.produce("file_results", value=json.dumps(payload).encode("utf-8"))
    producer.flush()


def process_ingestion(data):
    """Lógica principal que adapta tu ingest_from_s3 al flujo de eventos"""
    metadata = data["metadata"]
    ingestion = data["ingestion"]
    params = data["params"]  # Los **kwargs dinámicos desde Rails

    bank_name = metadata["bank"]
    source_id = metadata["source_file_id"]

    try:
        extractor_func = get_extractor(bank_name)
        df = pd.DataFrame()

        # CASO 1: Ingesta desde S3 (MinIO)
        if ingestion["type"] == "s3_storage":
            s3 = get_s3_client()
            print(f"📥 Descargando {ingestion['location']} desde S3...")
            response = s3.get_object(Bucket=ingestion["bucket"], Key=ingestion["location"])
            file_content = response["Body"].read()

            # Pasamos file_content y los kwargs dinámicos al extractor
            df = extractor_func(file_content, **params)

        # CASO 2: Ingesta desde API Externa (AMEX / Google Sheets)
        elif ingestion["type"] == "external_api":
            print(f"🌐 Iniciando extracción vía API para {bank_name}...")
            # Aquí el extractor_func debe estar preparado para no recibir un archivo
            df = extractor_func(None, **params)

        # PROCESAMIENTO COMÚN
        if not df.empty:
            count = len(df)
            df["event_id"] = df.apply(generate_event_id, axis=1)

            # origen: definitivo para PDF, parcial para Excel/CSV/Sheets
            pdf_banks = {"bbva_pdf_visa", "bbva_pdf_mastercard", "bapro_pdf_visa", "bapro_pdf_mastercard", "amex_pdf"}
            origen = "definitivo" if bank_name in pdf_banks else "parcial"
            df["origen"] = origen

            # fecha_vencimiento: extraído del PDF (cuando es correcto) o params (UI)
            if "fecha_vencimiento" not in df.columns and params.get("fecha_vencimiento"):
                df["fecha_vencimiento"] = params["fecha_vencimiento"]

            for _, row in df.iterrows():
                row_dict = row.to_dict()
                # Serializar fecha_vencimiento si es Timestamp/date
                if "fecha_vencimiento" in row_dict and pd.notna(row_dict.get("fecha_vencimiento")):
                    fv = row_dict["fecha_vencimiento"]
                    row_dict["fecha_vencimiento"] = (
                        fv.strftime("%Y-%m-%d") if hasattr(fv, "strftime") else str(fv)
                    )
                producer.produce(
                    "transacciones_raw",
                    key=str(row["event_id"]).encode(),
                    value=json.dumps(row_dict, default=json_serial).encode("utf-8"),
                )

            producer.flush()
            send_feedback(
                source_id,
                "success",
                extractor=bank_name,
                transactions_count=count,
                message=f"{count} transacciones procesadas",
            )
            print(f"✅ '{bank_name}' completada: {count} registros enviados.")
        else:
            send_feedback(
                source_id,
                "success",
                extractor=bank_name,
                transactions_count=0,
                message="Archivo vacío, 0 transacciones extraídas",
            )
            print(f"⚠️ El extractor de {bank_name} devolvió un DataFrame vacío.")

    except Exception as e:
        print(f"❌ Error procesando {bank_name}: {e}")
        send_feedback(
            source_id,
            "failed",
            error=str(e),
            extractor=bank_name,
            transactions_count=None,
            message=None,
        )


def run_worker():
    print("running run_worker")
    consumer_conf = {
        "bootstrap.servers": os.getenv("KAFKA_SERVERS", "redpanda:29092"),
        "group.id": "ingestion-engine-group-2026",
        "auto.offset.reset": "earliest",
    }

    consumer = Consumer(consumer_conf)
    consumer.subscribe(["file_uploaded"])

    print(f"🤖 Ingestion Engine activo. Extractores: {list_extractors()}")

    try:
        while True:
            msg = consumer.poll(1.0)
            print(f"msg : {msg}")
            if msg is None:
                continue
            if msg.error():
                print(f"Kafka error: {msg.error()}")
                continue

            # Parsear el evento que viene de Rails
            event_data = json.loads(msg.value().decode("utf-8"))
            process_ingestion(event_data)
    finally:
        consumer.close()


if __name__ == "__main__":
    run_worker()
