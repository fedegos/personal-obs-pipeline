import json
import os
from typing import Any

import pandas as pd
from confluent_kafka import Consumer, Producer

from bank_extractors import get_extractor, list_extractors
from utils.data_standardizer import generate_event_id
from utils.logging_config import get_logger
from utils.s3_client import get_s3_client

logger = get_logger(__name__)

producer_conf = {"bootstrap.servers": os.getenv("KAFKA_SERVERS", "redpanda:29092")}
producer = Producer(producer_conf)


def json_serial(obj: Any) -> str:
    """Serializa objetos pandas a formato JSON."""
    if isinstance(obj, (pd.Timestamp, pd.DatetimeIndex)):
        return obj.isoformat()
    return str(obj)


def send_feedback(
    source_file_id: int,
    status: str,
    error: str | None = None,
    extractor: str | None = None,
    transactions_count: int | None = None,
    message: str | None = None,
) -> None:
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


def process_ingestion(data: dict[str, Any]) -> None:
    """Lógica principal que adapta tu ingest_from_s3 al flujo de eventos."""
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
            logger.info("Descargando %s desde S3...", ingestion["location"])
            response = s3.get_object(Bucket=ingestion["bucket"], Key=ingestion["location"])
            file_content = response["Body"].read()

            df = extractor_func(file_content, **params)

        # CASO 2: Ingesta desde API Externa (AMEX / Google Sheets)
        elif ingestion["type"] == "external_api":
            logger.info("Iniciando extracción vía API para %s...", bank_name)
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
            logger.info("'%s' completada: %d registros enviados.", bank_name, count)
        else:
            send_feedback(
                source_id,
                "success",
                extractor=bank_name,
                transactions_count=0,
                message="Archivo vacío, 0 transacciones extraídas",
            )
            logger.warning("El extractor de %s devolvió un DataFrame vacío.", bank_name)

    except Exception as e:
        logger.exception("Error procesando %s: %s", bank_name, e)
        send_feedback(
            source_id,
            "failed",
            error=str(e),
            extractor=bank_name,
            transactions_count=None,
            message=None,
        )


def run_worker() -> None:
    """Inicia el worker que consume eventos de Kafka."""
    logger.info("Iniciando Ingestion Engine worker...")
    consumer_conf = {
        "bootstrap.servers": os.getenv("KAFKA_SERVERS", "redpanda:29092"),
        "group.id": os.getenv("KAFKA_CONSUMER_GROUP", "ingestion-engine-group"),
        "auto.offset.reset": "earliest",
    }

    consumer = Consumer(consumer_conf)
    consumer.subscribe(["file_uploaded"])

    logger.info("Ingestion Engine activo. Extractores: %s", list_extractors())

    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                logger.error("Kafka error: %s", msg.error())
                continue

            event_data = json.loads(msg.value().decode("utf-8"))
            logger.debug("Mensaje recibido: %s", event_data.get("metadata", {}).get("source_file_id"))
            process_ingestion(event_data)
    finally:
        consumer.close()


if __name__ == "__main__":
    run_worker()
