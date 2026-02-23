# 🚀 Runbook: Personal Observability Pipeline (Audit-X)
*Actualizado: 29 de enero, 2026*

## 🔀 Flujo Git y CI
El trabajo se hace en ramas; la integración a `main` es solo vía Pull Request, con el CI en verde (lint y tests de Rails y Python). El workflow está en la raíz del repo: `.github/workflows/ci.yml`. Coolify despliega desde `main`.

> **Despliegue en Coolify:** Si el build falla (exit 255, timeout), consultar [COOLIFY-DEPLOYMENT.md](COOLIFY-DEPLOYMENT.md) para memoria, timeouts y optimizaciones.

---

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
- **Eventos Kafka (AsyncAPI):** [asyncapi.yaml](asyncapi.yaml) — Especificación de tópicos y payloads (transacciones_raw, transacciones_clean, file_uploaded, file_results, domain_events).
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
   *En producción, `rails db:migrate` crea también las tablas de Solid Cache y Solid Queue (Rack::Attack y Active Job).*

---

## 📥 3. Carga de archivos e ingesta

### Flujo completo

1. **Usuario sube archivo** en [http://localhost:3000/source_files](http://localhost:3000/source_files): selecciona banco, adjunta Excel/CSV/PDF (o conecta Google Sheets para AMEX).
2. **Rails (ExcelUploaderService)** guarda el archivo en MinIO y publica en el tópico `file_uploaded`.
3. **Python (ingestion_worker)** consume `file_uploaded`, descarga de MinIO, ejecuta el extractor según el banco, publica en `transacciones_raw` y en `file_results`.
4. **Rails (TransactionsConsumer)** consume `transacciones_raw` y persiste en PostgreSQL (pendientes de aprobación).
5. **Rails (FileResultsConsumer)** consume `file_results` y actualiza el estado del SourceFile (transacciones_count, extractor, mensaje).

### Bancos y extractores

| Banco | Tipo | Parámetros | Ubicación |
|-------|------|------------|-----------|
| `visa` | CSV | — | `bank_extractors/visa_extractor.py` |
| `bbva` | CSV/Excel | card_number, card_network | `bank_extractors/bbva_extractor.py` |
| `amex` | Google Sheets | credit_card, spreadsheet_id, sheet | `bank_extractors/amex_extractor.py` |
| `bbva_pdf_visa` | PDF | card_number | `bank_extractors/bbva_pdf_extractor.py` |
| `bapro_pdf_visa` | PDF | card_number | `bank_extractors/bapro_pdf_extractor.py` |
| `amex_pdf` | PDF | card_number, year | `bank_extractors/amex_pdf_extractor.py` |

Los parámetros se definen en `web-enrichment-app/config/initializers/bank_schemas.rb`. El formulario de carga los solicita dinámicamente según el banco.

### Listar archivos en MinIO

```bash
docker exec -it minio_s3 mc alias set local http://localhost:9000 {user} {password}
docker exec -it minio_s3 mc du local/bank-ingestion
```

---

## 🔍 4. Curaduría y aprobación (Rails)

En esta fase, los datos están en PostgreSQL pero **no han llegado a InfluxDB** hasta que se aprueben.

1. Entra a [http://localhost:3000/transactions](http://localhost:3000/transactions).
2. Revisa las categorías sugeridas por el `CategorizerService`.
3. Ajusta la categoría, subcategoría o sentimiento si es necesario.
4. **Edición en línea:** Los cambios se guardan automáticamente (auto-save) mientras la transacción sigue pendiente. El flag `manually_edited` evita que las reglas dinámicas sobrescriban correcciones manuales.
5. Presiona **"Aprobar"** para publicar en `transacciones_clean`.
6. **Aprobar similares:** Si varias transacciones comparten la misma categoría/sentimiento sugerida, puedes aprobarlas en bloque. El modal muestra el listado previo a confirmar.

### Audit corrections (correcciones en lote)

En [http://localhost:3000/audit_corrections](http://localhost:3000/audit_corrections) puedes corregir transacciones ya aprobadas. Navegación prev/siguiente entre registros; los cambios se republican en `transacciones_clean` para actualizar InfluxDB.

---

## 📊 5. Visualización (Telegraf + InfluxDB + Grafana)

El servicio **Telegraf** consume `transacciones_clean` y escribe en InfluxDB.

1. Abre **Grafana** [http://localhost:3001](http://localhost:3001).
2. Usa el Data Source de InfluxDB (Bucket: `finanzas` o el configurado en `INFLUX_BUCKET`).
3. En Flux, recuerda el contrato actual:
   - **Tags:** `event_id`, `moneda`, `red`, `fecha_vencimiento`
   - **Fields:** `monto`, `categoria`, `sentimiento`, `origen` (y otros)
   - Para filtrar `categoria`/`sentimiento`/`origen`, primero trae esos fields y aplica `pivot`.

### Estructura en InfluxDB (telegraf.conf)

- **Tags:** `event_id`, `moneda`, `red`, `fecha_vencimiento` (si está presente).
- **Fields:** `monto`, `categoria`, `sub_categoria`, `sentimiento`, `detalles`, `numero_tarjeta`, `en_cuotas`, `descripcion_cuota`, `origen`.
- **Timestamp:** `fecha` de la transacción.

### Campos `fecha_vencimiento` y `origen`

- **fecha_vencimiento:** Fecha de cierre o vencimiento del resumen (opcional). Útil para cargas parciales de Excel/CSV y para PDFs que incluyen esta fecha.
- **origen:** Indica el tipo de carga: `parcial` (cargas intermedias) o `definitivo` (resúmenes cerrados). Default: `definitivo`. En cargas Excel/CSV/Sheets suele ser `parcial`; en PDF de resumen, `definitivo`.

### Que tablero usar para cada pregunta

- **Vista rápida diaria:** `Audit-X - Overview`.
- **Como evoluciona el gasto en el año:** `Audit-X - Evolución Anual`.
- **Que categorias subieron o bajaron fuerte:** `Audit-X - Variaciones y Desvíos`.
- **Monitoreo operativo de datos no definitivos:** `Audit-X - Táctico Operativo`.
- **Patrones de consumo por dia del mes:** `Audit-X - Mapa Día del Mes`.
- **Seguimiento ejecutivo de acumulados:** `Audit-X - Acumulados`.

---

## ⚙️ Motor de Reglas y Extractores

### Reglas de categoría (export/import)

En [http://localhost:3000/category_rules](http://localhost:3000/category_rules) puedes:
- **Exportar:** descargar todas las reglas en JSON (jerárquico: raíz → hijos).
- **Importar:** subir un archivo JSON o pegar el contenido. El servicio es idempotente: unicidad por `name` + nivel (`parent_id`). Si existe una regla con el mismo nombre en el mismo nivel, se actualiza en lugar de duplicar.

Servicio: `CategoryRulesExportImportService`. Rutas: `GET /category_rules/export`, `POST /category_rules/import`.

### Extractores de ingesta (Python)

Extractores disponibles: Visa CSV, BBVA CSV, AMEX (Google Sheets), BBVA PDF Visa, BAPRO PDF Visa, AMEX PDF. Usan `pdfplumber` para PDF. Registrados en `ingestion-engine/bank_extractors/` y `web-enrichment-app/config/initializers/bank_schemas.rb`. Tests: `ingestion-engine/tests/test_extractors_pdf.py`, `test_extractors.py`.

---

## 💾 Backup y restauración

### Backup a demanda (todos los servicios)

| Target | Qué guarda | Salida |
|--------|------------|--------|
| `make backup-db` | PostgreSQL (desarrollo) | `backups/backup_dev_YYYYMMDD_HHMMSS.sql` |
| `make backup-db-test` | PostgreSQL (test) | `backups/backup_test_YYYYMMDD_HHMMSS.sql` |
| `make backup-influx` | InfluxDB (métricas, bucket) | `backups/influx_backup_YYYYMMDD_HHMMSS/` |
| `make backup-grafana` | Grafana (dashboards, datasources, usuarios) | `backups/grafana_YYYYMMDD_HHMMSS.tar.gz` |
| `make backup-minio` | MinIO (archivos subidos: Excel, PDF) | `backups/minio_YYYYMMDD_HHMMSS.tar.gz` |
| `make backup-redpanda` | Redpanda/Kafka (logs de tópicos) | `backups/redpanda_YYYYMMDD_HHMMSS.tar.gz` |
| **`make backup`** | Postgres + InfluxDB + Grafana + MinIO | Varios archivos en `backups/` |

La carpeta `backups/` está en `.gitignore`. Para InfluxDB se requieren `INFLUX_ORG` e `INFLUX_TOKEN` en `.env`.

### ¿Hace falta backup de MinIO y Kafka?

- **MinIO (S3):** **Sí, recomendado.** Contiene los archivos originales subidos (Excel, PDF). Si se pierden, no podrás re-procesar desde origen sin volver a subir. `make backup-minio` hace un volcado del volumen en un `.tar.gz`.
- **Kafka (Redpanda):** **Opcional.** Los mensajes en los tópicos se pueden re-alimentar desde Postgres (`recover-transactions-from-clean`) o re-subiendo archivos a MinIO y re-ingiriendo. El backup del volumen (`make backup-redpanda`) solo tiene sentido para **recuperación ante desastres** (restaurar el volumen completo); no es necesario para el día a día. Si prefieres no hacerlo, omítelo y usa `make backup` (que no incluye Redpanda) o ejecuta solo los targets que necesites.

### Restaurar Postgres (revertir cambios)
- **Desarrollo:** `make restore-db FILE=backups/backup_dev_YYYYMMDD_HHMMSS.sql` — **sobrescribe** la base de desarrollo. Cierra conexiones activas (p. ej. reinicia `web`) si falla por conexiones.
- **Test:** `make restore-db-test FILE=backups/backup_test_YYYYMMDD_HHMMSS.sql` — igual para la base de test.

Restaurar InfluxDB/Grafana/MinIO/Redpanda desde un backup requiere procedimientos manuales (ej. `influx restore`, reemplazar contenido del volumen de Grafana/MinIO). Consulta la documentación de cada servicio si lo necesitas.

### Backup automático en producción

En producción debe existir un **backup automático** (cron o job en Coolify/servidor). Ejemplo de script (`backup.sh`) para PostgreSQL + subida a MinIO:

```bash
#!/bin/bash
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_NAME="backup_audit_x_$TIMESTAMP.sql.gz"
CONTAINER_DB="$(docker ps -qf 'name=postgres' | head -1)"  # O el nombre del contenedor de Postgres

echo "📦 Iniciando dump..."
docker exec $CONTAINER_DB pg_dump -U postgres audit_x_prod | gzip > /tmp/$BACKUP_NAME

# Opcional: subir a MinIO/S3
# mc cp /tmp/$BACKUP_NAME myminio/backups-proyecto/
# find ... -mtime +30 -delete  # Retención

rm /tmp/$BACKUP_NAME
echo "✅ Backup completado: $BACKUP_NAME"
```

Para InfluxDB/Grafana/MinIO, usar los mismos targets que en desarrollo (`make backup-influx`, etc.). Ver [DOCS/DEVOPS-ROADMAP.md](DOCS/DEVOPS-ROADMAP.md) para prioridades.

### Rollback en Postgres
**No existe "rollback" de datos ya confirmados.** Una vez hecho `COMMIT`, la recuperación se hace **restaurando desde un backup**. Por eso el backup a demanda y automático es la pieza clave.

---

## 🔄 Recuperación y regeneración de transacciones (desde eventos)

Permite repoblar la tabla `transactions` desde los tópicos Kafka sin restaurar un backup de Postgres. Dos modos:

### Recuperación desde transacciones_clean (recovery desde eventos)

Rails **no** consume el tópico `transacciones_clean` en tiempo normal (solo Telegraf lo lee para InfluxDB). Para recuperar la base de datos desde los eventos ya aprobados:

- **Cuándo:** Tras pérdida de la tabla `transactions` o para repoblar desde la “fuente de verdad” que son los eventos clean.
- **Comando:** `make recover-transactions-from-clean`
- **Qué hace:** Un consumidor one-off (rdkafka) lee desde el inicio del tópico `transacciones_clean` y hace **upsert** por `event_id` en `transactions` (crea o actualiza, siempre con `aprobado: true`). Idempotente.
- **Limitación:** Los mensajes clean no incluyen `numero_tarjeta`; esos campos quedarán vacíos tras la recuperación. Opcionalmente se puede ejecutar después `make backfill-card-numbers` si los datos siguen en `transacciones_raw`.

Servicio: `RecoveryFromCleanService`. Rake: `rails data:recover_from_clean`. Tests: `bin/rails test test/services/recovery_from_clean_service_test.rb`.

### Regeneración desde transacciones_raw (rewind del circuito normal)

Relee el tópico `transacciones_raw` con el consumidor Karafka existente (`TransactionsConsumer`) para volver a crear las transacciones desde cero.

- **Cuándo:** Para “rebobinar” el flujo: borrar transacciones y repoblar desde raw (p. ej. tras cambiar reglas de categorización o corregir un bug en el consumer).
- **Comando:** `make regenerate-transactions-from-raw`
- **Qué hace:** 1) Borra solo la tabla `transactions` (`data:clean_transactions`). 2) Rebobina el consumer group `enrichment_manager_v3` al inicio del tópico (y de `file_results`). 3) Reinicia el worker Karafka. El worker vuelve a consumir todos los mensajes de `transacciones_raw` y crea de nuevo los registros en `transactions` (pendientes de aprobación).
- **Nota:** No hace falta modificar `TransactionsConsumer`; al borrar antes las transacciones, no hay registros aprobados que se salten.

Targets auxiliares:
- `make clean-transactions-only` — Borra solo `transactions` (no `SourceFile`).
- `make rebind-karafka-consumer` — Rebobina el consumer group al inicio.

### Backfill de numero_tarjeta

Las transacciones creadas antes de agregar el campo `numero_tarjeta` no tienen este dato. Los mensajes en Kafka `transacciones_raw` sí lo incluyen. Tras una recuperación desde `transacciones_clean` (que no incluye `numero_tarjeta`), o para completar registros antiguos:

**Opción recomendada (script directo):**

```bash
make backfill-card-numbers
```

El script (`DataBackfillService.backfill_numero_tarjeta`) lee desde el inicio del tópico `transacciones_raw`, busca cada transacción por `event_id` y actualiza solo el campo `numero_tarjeta` si está vacío. Idempotente. Presiona Ctrl+C para detener cuando quieras.

**Alternativa (rebind consumer):** Rebobinar el consumer group (`make rebind-karafka-consumer`) y reiniciar el worker. Requiere modificar temporalmente `TransactionsConsumer` para permitir actualizar aprobadas. Ver `make rebind-karafka-consumer` en el Makefile.

**Verificar resultados:**

```bash
docker compose exec web bin/rails runner "puts 'Con numero_tarjeta: ' + Transaction.where.not(numero_tarjeta: [nil, '']).count.to_s; puts 'Sin: ' + Transaction.where(numero_tarjeta: [nil, '']).count.to_s"
```

O usar `make check-card-numbers` para un resumen rápido.

**Notas:** Si Kafka ya purgó los mensajes (retención), no funcionará; habría que re-procesar los archivos originales desde MinIO. Si falla la conexión, verifica `docker compose ps redpanda` y `KAFKA_SERVERS` en `.env`.

---

## 📝 Notas Técnicas y Mantenimiento

1. **Idempotencia:** El `event_id` (hash SHA-256) previene duplicados. Si un gasto ya fue aprobado, el pipeline de Rails lo ignorará si intentas re-ingestarlo.
2. **Karafka Boot:** Si el worker no arranca, verifica que `app/consumers/application_consumer.rb` exista y que `karafka.rb` use `"TransactionsConsumer"` como string.
3. **Persistencia:** Los datos residen en volúmenes nombrados de Docker (`postgres_data`, `influxdb_data`). No borrar a menos que se desee un hard-reset.
4. **Sincronización:** Recuerda: **Escribe código en local, ejecuta en Docker.** Cualquier archivo generado con `rails generate` aparecerá en tu carpeta local gracias a los volúmenes montados.

---
*Tip: Usa `Ctrl + Shift + V` en VS Code para previsualizar este documento.*
