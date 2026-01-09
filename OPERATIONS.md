# 🚀 Runbook: Personal Observability Pipeline


# 🛠 1. Gestión de Infraestructura (Docker)
Desde la raíz del proyecto, usa estos comandos para controlar el stack:

*   **Construir imágenes por primera vez:**
    ```bash
    docker compose build
    ```
*   **Levantar todos los servicios (modo background):**
    ```bash
    docker compose up -d
    ```
*   **Ver estados y logs en tiempo real:**
    ```bash
    docker compose ps
    docker compose logs -f web
    ```
*   **Apagar todo:**
    ```bash
    docker compose down
    ```

    
- InfluxDB: http://localhost:8086 (Admin / password12345)
- Grafana: http://localhost:3000 (admin / admin)
- Redpanda Console (Kafka): http://localhost:8080 (si la activaste)

## 💎 2. Configuración Inicial de la App (Solo la primera vez)
Una vez que los contenedores estén corriendo, debes preparar la base de datos de Rails:
```bash
docker compose run web bin/rails db:create db:migrate
```

## 📥 3. Fase de Ingesta (Python)
Para cargar nuevos datos desde el Excel:

```bash
cd ingestion
# Instalar dependencias la primera vez:
# pip install -r requirements.txt
python ingest.py
```

## 💎 4. Aplicación de Enriquecimiento (Rails)
Para procesar y etiquetar los datos:

```bash
cd rails_app
# Iniciar servidor web
bin/rails s
# Iniciar consumidor de Kafka (¡IMPORTANTE para recibir datos del Excel!)
bundle exec karafka server
```

## 🧹 5. Limpieza y Mantenimiento

Para apagar todo y borrar volúmenes (reset total):

```bash
docker compose down -v
```

## 📝 Notas de Mañana

El ID de las transacciones se genera con SHA-256 en ingest.py.
Si el Excel se recarga, Rails ignora los IDs que ya tengan enriched: true.


1. Karafka Worker: El servicio karafka_server en Docker debe estar corriendo para que las transacciones pasen del "Excel" a la "App Web".
2. Idempotencia: No te preocupes por recargar el Excel; el event_id generado por Python evitará duplicados en la base de datos gracias a la validación de Rails.
3. Persistencia: Los datos de Postgres, Influx y Grafana se guardan en la carpeta local ./docker_data.

### 3. Tip para VS Code
Para que sea aún más útil mañana, presiona `Ctrl + Shift + V` (o `Cmd + Shift + V` en Mac) mientras tienes el archivo abierto en VS Code. Esto abrirá la **Vista Previa de Markdown**, permitiéndote ver los comandos y enlaces de forma interactiva y profesional. [Documentación de Markdown en VS Code](code.visualstudio.com).



