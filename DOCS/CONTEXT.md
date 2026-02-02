---
name: Resumen contexto migración WSL
overview: "Documento de contexto para pegar en el nuevo workspace WSL: resumen de lo hecho en la historia del proyecto y lo que queda pendiente."
todos: []
isProject: false
---

# Resumen de contexto: Personal OBS Pipeline (Audit-X) — Migración a WSL

Documento para agregar como contexto al nuevo workspace. Copiar y pegar en un archivo (p. ej. `CONTEXTO-WORKSPACE.md` en la raíz o en DOCS) o en las notas del proyecto.

---

## 1. Qué es el proyecto

- **Nombre:** Personal Observability Pipeline / Audit-X (Centro de Operaciones 2026).
- **Repositorio:** Pipeline de datos financieros: ingesta (Python) → Kafka → enriquecimiento/curaduría (Rails) → Telegraf → InfluxDB → Grafana.
- **Stack:** Docker Compose (Postgres, Redpanda/Kafka, InfluxDB, Grafana, MinIO, Redis, Rails web, Karafka worker, ingestion_worker Python, Telegraf).
- **Docs clave:** [README.md](README.md), [DOCS/OPERATIONS.md](DOCS/OPERATIONS.md), [DOCS/ROADMAP-RAILS-MEJORADO.md](DOCS/ROADMAP-RAILS-MEJORADO.md).

---

## 2. Lo que se hizo en esta historia (resumen)

### AsyncAPI y validación

- Creado [DOCS/asyncapi.yaml](DOCS/asyncapi.yaml) para describir eventos Kafka (transacciones_raw, transacciones_clean, file_uploaded, file_results, domain_events).
- Referencias en README y OPERATIONS.
- Target `make validate-asyncapi` (valida con `npx @asyncapi/cli`).

### Tests de Rails (profiling y optimización)

- Target `make test-profile` (TESTOPTS="--profile 25") para ver los 25 tests más lentos.
- [DOCS/TEST-PROFILING.md](DOCS/TEST-PROFILING.md): causas de lentitud y mejoras.
- **test_helper.rb:** lógica de `parallelize` corregida (si `PARALLEL_WORKERS` no está definido se usa `:number_of_processors`; antes se usaba 0 por bug). Fixtures por archivo: quitado `fixtures :all`; cada test declara solo los fixtures que usa (`fixtures :users, :category_rules`, etc.). **Stub global de Karafka:** `Karafka.producer` reemplazado por no-op para que los tests no escriban a los tópicos de desarrollo.
- Resultado: tiempo total de tests ~9s → ~5s; CategoryRulesControllerTest ~5–7s → ~0,6–2,7s por test.
- Targets de test usan `RAILS_ENV=test` para evitar `EnvironmentMismatchError` (DB de test `rails_app_test`).

### Extractor BBVA PDF (dólares)

- [ingestion-engine/bank_extractors/bbva_pdf_extractor.py](ingestion-engine/bank_extractors/bbva_pdf_extractor.py): transacciones en dólares se interpretaban como pesos (columna PESOS vacía, regex tomaba el monto en USD).
- Añadido regex para detectar " USD " en la línea; prioridad a `moneda = "dolares"` y monto extraído de " USD X,XX"; limpieza de la descripción. Regex adicional para columna PESOS vacía (espacios entre cupón y monto USD).
- Test en `tests/test_extractors_pdf.py` para USD en línea.

### Recuperación y regeneración de transacciones

- Servicio `RecoveryFromCleanService`: lee `transacciones_clean`, upsert en `transactions` (aprobado: true). Rake `data:recover_from_clean` y `data:clean_transactions`.
- Targets Make: `recover-transactions-from-clean`, `clean-transactions-only`, `regenerate-transactions-from-raw`.
- Documentado en OPERATIONS.md (recuperación desde clean y regeneración desde raw).

### Backups a demanda

- **Makefile:** `backup-db`, `backup-db-test` (ya existían); nuevos: `backup-influx`, `backup-grafana`, `backup-minio`, `backup-redpanda`; meta `make backup` = Postgres + Influx + Grafana + MinIO (sin Redpanda).
- InfluxDB: `influx backup` dentro del contenedor, luego `docker cp` a `backups/influx_backup_YYYYMMDD_HHMMSS/`.
- Grafana: `docker compose exec grafana tar czf - ... > backups/grafana_....tar.gz` (sin Alpine).
- MinIO y Redpanda: `docker compose run --rm --no-deps -v minio_data:/data:ro` (y `redpanda_data`) con servicio **web** para hacer el tar (evitar pull de Alpine y error de credenciales Docker).
- OPERATIONS.md: tabla de backups, criterio “MinIO sí / Kafka opcional”, y que restaurar Influx/Grafana/MinIO/Kafka es manual.

### Otros

- `make build-ingestion` para reconstruir imagen del worker Python tras cambiar requirements.txt.
- `make restart-ingestion` para reiniciar el contenedor ingestion_worker.
- Resolución de conflictos en OPERATIONS.md (cherry-pick con solid_cache/solid_queue).
- RuboCop `Layout/SpaceInsideArrayLiteralBrackets` corregido en tests de Rails.

---

## 3. Lo que queda pendiente (para adelante)

### Del [DOCS/TODO.md](DOCS/TODO.md) (pendiente inmediato antiguo)

- Crear archivo de prueba `datos_banco.xlsx` para que Python tenga qué leer (si aplica).
- Karafka ya apunta a localhost:9092 (o al broker del compose); verificar en [config/karafka.rb](web-enrichment-app/config/karafka.rb) si hay algo por ajustar en el nuevo entorno.
- Callbacks en Transaction para enviar a InfluxDB al marcar enriquecido: el flujo actual es transacciones_clean → Telegraf → InfluxDB; confirmar si hace falta callback adicional.

### DevOps y operaciones ([DOCS/DEVOPS-ROADMAP.md](DOCS/DEVOPS-ROADMAP.md))

- Backup automatizado en producción (Postgres, InfluxDB, retención).
- Health checks avanzados: `/health`, `/ready`, `/live` (Postgres, Redis, Kafka).
- Logging estructurado (JSON, request_id, niveles).
- Secretos y variables de entorno en producción (no en .env en repo).

### Posibles mejoras de tests

- Seguir reduciendo tiempos si hace falta (menos workers con `PARALLEL_WORKERS=2`, o no ejecutar `db:test:prepare` en cada iteración local).
- Ver [DOCS/TEST-PROFILING.md](DOCS/TEST-PROFILING.md).

### WSL / entorno

- Si aparece `make: getcwd: No such file or directory`, ejecutar `make` desde la raíz del proyecto y no borrar/renombrar el directorio durante la ejecución; o abrir nueva terminal y `cd` de nuevo al proyecto.
- En WSL, paths como `/mnt/c/desarrollos/...`; en el nuevo workspace probablemente sea algo como `~/...` o `/home/...`. Revisar `.env` y rutas si algo falla.

---

## 4. Comandos útiles (recordatorio)


| Comando                                 | Uso                                                         |
| --------------------------------------- | ----------------------------------------------------------- |
| `make up`                               | Levantar stack                                              |
| `make backup`                           | Backup Postgres + Influx + Grafana + MinIO                  |
| `make test`                             | Tests Rails (RAILS_ENV=test)                                |
| `make test-profile`                     | Tests con perfil de los 25 más lentos                       |
| `make recover-transactions-from-clean`  | Repoblar transactions desde transacciones_clean             |
| `make regenerate-transactions-from-raw` | Borrar transactions, rebobinar consumer, repoblar desde raw |
| `make validate-asyncapi`                | Validar DOCS/asyncapi.yaml                                  |


---

## 5. Dónde está cada cosa

- **Eventos Kafka:** [DOCS/asyncapi.yaml](DOCS/asyncapi.yaml).
- **Runbook y backups:** [DOCS/OPERATIONS.md](DOCS/OPERATIONS.md).
- **Profiling de tests:** [DOCS/TEST-PROFILING.md](DOCS/TEST-PROFILING.md).
- **Backfill numero_tarjeta:** [DOCS/BACKFILL-NUMERO-TARJETA.md](DOCS/BACKFILL-NUMERO-TARJETA.md).
- **Roadmap DevOps:** [DOCS/DEVOPS-ROADMAP.md](DOCS/DEVOPS-ROADMAP.md).
- **Configuración tests:** [web-enrichment-app/test/test_helper.rb](web-enrichment-app/test/test_helper.rb) (parallelize, fixtures por archivo).

Al pegar este resumen en el nuevo workspace tendrás el contexto de lo hecho y lo pendiente sin depender del historial de chat.