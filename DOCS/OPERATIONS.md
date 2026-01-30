# 🚀 Runbook: Personal Observability Pipeline (Audit-X)
*Actualizado: 29 de enero, 2026*

## 🔀 Flujo Git y CI
El trabajo se hace en ramas; la integración a `main` es solo vía Pull Request, con el CI en verde (lint y tests de Rails y Python). El workflow está en la raíz del repo: `.github/workflows/ci.yml`. Coolify despliega desde `main`.

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

## ⚙️ Motor de Reglas y Extractores

### Reglas de categoría (export/import)
En [http://localhost:3000/category_rules](http://localhost:3000/category_rules) puedes:
- **Exportar:** descargar todas las reglas en JSON (jerárquico: raíz → hijos).
- **Importar:** subir un archivo JSON o pegar el contenido; el servicio crea/actualiza reglas por `name` + `pattern` + `parent_name` (idempotente).

Servicio: `CategoryRulesExportImportService` (export/import). Rutas: `GET /category_rules/export`, `POST /category_rules/import`.

### Extractores de ingesta (Python)
Además de los extractores por banco (Visa, Amex, BBVA CSV), existe el extractor **BBVA PDF Visa** (`bbva_pdf_visa`) para resúmenes de tarjeta en PDF. Usa `pdfplumber`; está registrado en `ingestion-engine/bank_extractors/` y en `web-enrichment-app/config/initializers/bank_schemas.rb`. Tests: `ingestion-engine/tests/test_extractors_pdf.py`.

---

## 💾 Backup y restauración de bases de datos

### Backup a demanda (desarrollo y test)
- **Base de desarrollo:** `make backup-db` — guarda un volcado en `backups/backup_dev_YYYYMMDD_HHMMSS.sql`. La carpeta `backups/` está en `.gitignore`.
- **Base de test:** `make backup-db-test` — guarda en `backups/backup_test_YYYYMMDD_HHMMSS.sql`.

### Restaurar (revertir cambios)
- **Desarrollo:** `make restore-db FILE=backups/backup_dev_YYYYMMDD_HHMMSS.sql` — **sobrescribe** la base de desarrollo con el dump indicado. Cierra conexiones activas (p. ej. reinicia `web`) si falla por conexiones.
- **Test:** `make restore-db-test FILE=backups/backup_test_YYYYMMDD_HHMMSS.sql` — igual para la base de test.

### Backup automático en producción
En producción debe existir un **backup automático** (cron o job en Coolify/servidor) que ejecute `pg_dump` contra la base de producción (`audit_x_prod`) y guarde los archivos con retención (ej. 7 días diarios). No forma parte del repo de la aplicación; es tarea de infraestructura. Ver ejemplos en [DOCS/INFRA_MEMORANDUM.md](DOCS/INFRA_MEMORANDUM.md) (script `backup.sh`) y [DOCS/DEVOPS-ROADMAP.md](DOCS/DEVOPS-ROADMAP.md) (sección Backup Automatizado). Para restaurar en producción: mismo concepto que `restore-db` pero contra la DB de producción y con precaución extra (ventana de mantenimiento, notificación).

### Rollback en Postgres
**No existe "rollback" de datos ya confirmados.** Una vez hecho `COMMIT`, no hay comando para deshacer esa transacción. La recuperación se hace **restaurando desde un backup** (pg_dump/pg_restore o PITR si está configurado). Por eso el backup a demanda y automático es la pieza clave para poder revertir.

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
- `make rebind-karafka-consumer` — Rebobina el consumer group al inicio (útil también para backfill de `numero_tarjeta` si se combina con lógica que permita actualizar aprobadas).

---

## 📝 Notas Técnicas y Mantenimiento

1. **Idempotencia:** El `event_id` (hash SHA-256) previene duplicados. Si un gasto ya fue aprobado, el pipeline de Rails lo ignorará si intentas re-ingestarlo.
2. **Karafka Boot:** Si el worker no arranca, verifica que `app/consumers/application_consumer.rb` exista y que `karafka.rb` use `"TransactionsConsumer"` como string.
3. **Persistencia:** Los datos residen en volúmenes nombrados de Docker (`postgres_data`, `influxdb_data`). No borrar a menos que se desee un hard-reset.
4. **Sincronización:** Recuerda: **Escribe código en local, ejecuta en Docker.** Cualquier archivo generado con `rails generate` aparecerá en tu carpeta local gracias a los volúmenes montados.

### Hotfix: `solid_cache_entries` / Solid Queue no existen (401 en login)
Si en producción aparece **`PG::UndefinedTable: relation "solid_cache_entries" does not exist`** al hacer login (porque Rack::Attack usa Solid Cache para throttling):

- **Opción A (recomendada):** Desplegar este hotfix y ejecutar migraciones en producción:
  ```bash
  RAILS_ENV=production bundle exec rails db:migrate
  ```
  Las migraciones `20260130120000_create_solid_cache_entries` y `20260130120001_create_solid_queue_tables` crean las tablas en la base principal.

- **Opción B (sin redesplegar):** En el servidor de producción, con la app ya desplegada:
  ```bash
  cd /ruta/a/web-enrichment-app
  RAILS_ENV=production bundle exec rails db:schema:load:cache
  RAILS_ENV=production bundle exec rails db:schema:load:queue
  ```
  Eso carga los esquemas de cache y queue en la misma base (si usas una sola `DATABASE_URL`).

---
*Tip: Usa `Ctrl + Shift + V` en VS Code para previsualizar este documento.*
