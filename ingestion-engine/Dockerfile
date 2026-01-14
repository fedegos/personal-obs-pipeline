# ingestion-engine/Dockerfile
FROM python:3.11-slim

WORKDIR /app

# Dependencias para confluent-kafka y herramientas de compilación
RUN apt-get update && apt-get install -y \
    build-essential \
    librdkafka-dev \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copiamos todo el contenido (incluyendo la carpeta extractors/)
COPY . .

# Comando para iniciar el consumidor
CMD ["python", "main.py"]
