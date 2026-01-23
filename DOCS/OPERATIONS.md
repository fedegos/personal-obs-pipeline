# 🚀 Runbook: Personal Observability Pipeline (Audit-X)
*Actualizado: 10 de enero, 2026*

## 🛠 1. Gestión de Infraestructura (Docker)
El stack completo corre en contenedores. No es necesario instalar Ruby o Kafka localmente.

*   **Levantar el stack (Recomendado):**
    ```bash
    docker compose up -d
    ```
*   **Verificar salud de los servicios (Healthchecks):**
    ```bash
    docker compose ps
    ```
    *Nota: `redpanda` y `db` deben aparecer como `(healthy)` antes de que `web` inicie.*
*   **Logs específicos para depurar:**
    ```bash
    docker compose logs -f web            # Logs de la interfaz Rails
    docker compose logs -f karafka_worker # Logs del consumidor de Kafka
    ```
*   **Apagar y limpiar volúmenes (Reset de DBs):**
    ```bash
    docker compose down -v
    ```

### 🌐 Dashboard de Control
- **Audit-X (Rails):** [http://localhost:3000](http://localhost:3000) (Gestión y Aprobación)
- **Kafka UI:** [http://localhost:8080](http://localhost:8080) (Monitoreo de tópicos)
- **Grafana:** [http://localhost:3001](http://localhost:3001) (Visualización final)
- **InfluxDB:** [http://localhost:8086](http://localhost:8086) (Métricas Raw)

---

## 💎 2. Configuración Inicial (Instalación)
Si agregaste gemas nuevas o estás en una instalación limpia:

1. **Sincronizar Gemas:**
   ```bash
   docker compose run --rm web bundle install
   ```
2. **Preparar Base de Datos:**
   ```bash
   docker compose exec web rails db:prepare
   ```


---

## 📥 3. Fase 1: Ingesta (Python)
Envía los datos de los extractores (Visa/Amex) hacia Kafka.

```bash
# Activar entorno virtual
source .venv/bin/activate
# Ejecutar ingesta
python main.py
```
*Los eventos quedarán en el tópico `transacciones_raw` y entrarán automáticamente a la web de Rails en estado "Pendiente".*

2. **Listar archivos en s3:**
```bash
docker exec -it minio_s3 mc alias set local http://localhost:9000 {user} {password}
```

```bash
docker exec -it minio_s3 mc du local/bank-ingestion
```
---

## 🔍 4. Fase 2: Curaduría y Enriquecimiento (Rails)
En esta fase, los datos están en PostgreSQL pero **no han llegado a InfluxDB**.

1. Entra a [http://localhost:3000/transactions](http://localhost:3000/transactions).
2. Revisa las categorías sugeridas por el `CategorizerService`.
3. Ajusta la categoría o el sentimiento si es necesario.
4. Presiona **"Aprobar"**. 
   *Esto publica el evento en `transacciones_clean`.*

---

## 📊 5. Fase 3: Visualización (Telegraf + Influx + Grafana)
El servicio **Telegraf** está configurado para mover automáticamente todo lo que aparece en el tópico `transacciones_clean` hacia InfluxDB.

1. Abre **Grafana** [http://localhost:3001](http://localhost:3001).
2. Usa el Data Source de InfluxDB (Bucket: `finanzas`).
3. Filtra por los tags: `categoria`, `sentimiento` o `red`.

---

## 📝 Notas Técnicas y Mantenimiento

1. **Idempotencia:** El `event_id` (hash SHA-256) previene duplicados. Si un gasto ya fue aprobado, el pipeline de Rails lo ignorará si intentas re-ingestarlo.
2. **Karafka Boot:** Si el worker no arranca, verifica que `app/consumers/application_consumer.rb` exista y que `karafka.rb` use `"TransactionsConsumer"` como string.
3. **Persistencia:** Los datos residen en volúmenes nombrados de Docker (`postgres_data`, `influxdb_data`). No borrar a menos que se desee un hard-reset.
4. **Sincronización:** Recuerda: **Escribe código en local, ejecuta en Docker.** Cualquier archivo generado con `rails generate` aparecerá en tu carpeta local gracias a los 

---
*Tip: Usa `Ctrl + Shift + V` en VS Code para previsualizar este documento.*
```` [1], [2], [3]
