# Audit-X Operations 2026

ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: clean-db clean-influx clean-kafka reset-history help ci ci-rails-lint ci-rails-rubocop ci-rails-test ci-test-rails ci-rails-system-test ci-python-lint ci-python-test logs-web build-web backup-db backup-db-test restore-db restore-db-test validate-asyncapi recover-transactions-from-clean clean-transactions-only regenerate-transactions-from-raw fix fix-rails fix-python

.DEFAULT_GOAL := help

help: ## Muestra esta ayuda
	@echo "-----------------------------------------------------------------------"
	@echo "Audit-X DevOps Commands (2026)"
	@echo "-----------------------------------------------------------------------"
	@grep -Eh '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'


rewind-web-transactions: ## Vuelve a emitir eventos en transacciones_clean de registros con aprobado: true
	@echo "⏪ Reprocesando transacciones aprobadas"
	docker compose exec web rake data:replay_clean

rewind-kafka: ## Resetear el puntero de Telegraf al inicio (sin borrar el tópico)
	@echo "⏪ Rebobinando puntero de Telegraf al inicio..."
	docker compose stop telegraf
	docker compose exec redpanda rpk group seek telegraf_metrics_group_v4 --to start
	docker compose start telegraf

reprocess-all: clean-influx rewind-kafka ## Limpieza total y REPROCESAMIENTO (Blanqueo + Relectura). Este comando borra Influx pero NO borra Kafka, solo lo rebobina
	@echo "✅ InfluxDB limpio y Kafka rebobinado. Telegraf está recreando los datos..."


clean-db: ## PostgreSQL: Borra transacciones e historial de carga, mantiene reglas (CategoryRules)
	@echo "🧹 Borrando registros operativos en Postgres (Transactions & SourceFiles)..."
	docker compose exec web rails runner "Transaction.delete_all; SourceFile.delete_all rescue nil"

clean-influx: ## InfluxDB: Borra puntos de datos usando las variables del .env
	@echo "🧹 Borrando métricas en InfluxDB (Bucket: $(INFLUX_BUCKET))..."
	docker compose exec influxdb influx delete \
		--bucket "$(INFLUX_BUCKET)" \
		--start 1970-01-01T00:00:00Z \
		--stop $$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
		--org "$(INFLUX_ORG)" \
		--token "$(INFLUX_TOKEN)"

clean-kafka: ## Redpanda (Kafka): Limpieza dinámica de todos los tópicos activos
	@echo "🧹 Vaciando todas las colas de Kafka (Redpanda)..."
	@# Filtramos tópicos internos (__), los borramos y recreamos
	docker compose exec redpanda bash -c 'for topic in $$(rpk topic list | awk "NR>1 {print \$$1}" | grep -v "__"); do \
		rpk topic delete $$topic; \
		rpk topic create $$topic; \
	done'

reset-history: clean-db clean-influx clean-kafka ## COMBO: Blanqueo total de actividad operativa
	@echo "✅ Operación completada: Las reglas de categorización se preservaron."
	@echo "✅ El bucket '$(INFLUX_BUCKET)' y las colas de Kafka están vacíos."

up: ## Levantar todo en segundo plano
	docker compose up -d

build-web: ## Reconstruir imagen del servicio web (hacer tras cambiar Gemfile/Gemfile.lock)
	docker compose build web

build-ingestion: ## Reconstruir imagen del worker Python (hacer tras cambiar requirements.txt)
	docker compose build ingestion_worker

logs: ## Ver logs de todos los servicios con timestamps
	docker compose logs -f -t

logs-web: ## Ver logs solo del servicio web (Rails). Usa el nombre del servicio, no del contenedor (rails_app).
	docker compose logs -f web

down: ## Bajar todo sin limpiar volúmenes
	docker compose down

restart-all: down up ## Reiniciar todos los contenendores.

restart-web: ## Reiniciar la web.
	docker compose restart web

down-volumes: ## Bajar todo y limpiar volúmenes (atención: borra datos persistentes)
	docker compose down -v

restart-karafka-worker: ## Reiniciar solo el worker de Rails (útil cuando cambias lógica de Karafka)
	docker compose restart karafka_server

shell-web: ## Entrar a la consola de Rails (2026 mode)
	docker compose exec web rails console

inspect-kafka: ## Inspeccionar el broker de Kafka (ver tópicos y lag de consumidores)
	docker compose exec redpanda rpk cluster status
	docker compose exec redpanda rpk topic list
	docker compose exec redpanda rpk group describe telegraf_metrics_group_v4

inspect-influx: ## Ver qué está llegando exactamente a InfluxDB en tiempo real
	docker compose exec influxdb influx query \
		'from(bucket: "$(INFLUX_BUCKET)") |> range(start: -5m) |> limit(n:10)' \
		--org "$(INFLUX_ORG)" --token "$(INFLUX_TOKEN)"

test: ## Correr tests de Rails (Minitest). Usa RAILS_ENV=test para no tocar la DB de desarrollo.
	docker compose exec -e RAILS_ENV=test web bin/rails db:test:prepare test

test-python: ## Correr tests de Python (pytest)
	cd ingestion-engine && python3 -m pytest tests/ -v --tb=short

test-all: test test-python ## Correr todas las pruebas (Rails + Python)

# --- CI local: mismos checks que GitHub Actions (.github/workflows/ci.yml) ---
ci-rails-lint: ## CI: Brakeman + bundler-audit + importmap audit
	docker compose exec web bin/brakeman --no-pager
	docker compose exec web bin/bundler-audit
	docker compose exec web bin/importmap audit

ci-rails-rubocop: ## CI: RuboCop (solo verificación, sin -A)
	docker compose exec web bin/rubocop -f github

ci-rails-test: ## CI: Minitest (RAILS_ENV=test → DB rails_app_test, no desarrollo)
	docker compose exec -e RAILS_ENV=test web bin/rails db:test:prepare test

ci-test-rails: ci-rails-test ## Alias: mismo que ci-rails-test

ci-rails-system-test: ## CI: System tests (RAILS_ENV=test → DB rails_app_test)
	docker compose exec -e RAILS_ENV=test web bin/rails db:test:prepare test:system

ci-python-lint: ## CI: Ruff check (dentro del contenedor ingestion_worker)
	docker compose exec ingestion_worker python3 -m ruff check .

ci-pyhon-lint: ci-python-lint ## Alias (typo) → ci-python-lint

ci-python-test: ## CI: pytest (dentro del contenedor ingestion_worker)
	docker compose exec ingestion_worker python3 -m pytest tests/ -v --tb=short

ci: ci-rails-lint ci-rails-rubocop ci-rails-test ci-rails-system-test ci-python-lint ci-python-test ## Correr todos los controles del CI (igual que GitHub Actions)

security-check: ## Verificar vulnerabilidades en gemas (Seguridad 2026)
	docker compose exec web bundle exec bundle-audit update
	docker compose exec web bundle exec bundle-audit check
	docker compose exec web bundle exec brakeman

lint: ## Linting de Ruby (Estilo de código, con auto-fix) — alias de fix-rails
	$(MAKE) fix-rails

# --- Auto-corregir errores de lint (modifican archivos) ---
fix-rails: ## Corregir estilo Ruby: RuboCop -A (safe + unsafe) en web-enrichment-app
	docker compose exec web bin/rubocop -A

fix-python: ## Corregir estilo Python: Ruff check --fix + format en ingestion-engine
	docker compose exec ingestion_worker python3 -m ruff check --fix .
	docker compose exec ingestion_worker python3 -m ruff format .

fix: fix-rails fix-python ## Corregir lint en Rails y Python (ejecuta fix-rails y fix-python)

setup: up ## Preparar todo el sistema desde cero
	docker compose exec web bundle install
	docker compose exec web rails db:prepare
	docker compose exec web rails db:seed
	@echo "✅ Sistema listo en http://localhost:3000"

migrate: ## Ejecutar migraciones de Rails (dentro del contenedor web)
	docker compose exec web rails db:migrate

seed: ## Ejecutar seeds de Rails (dentro del contenedor web)
	docker compose exec web rails db:seed

backup-rules: ## Exportar las CategoryRules a un archivo YAML
	docker compose exec web rails runner "File.write('db/category_rules_backup.yml', CategoryRule.all.to_yaml)"
	@echo "💾 Reglas exportadas a db/category_rules_backup.yml"

backup-db: ## Volcado de la base de desarrollo (pg_dump) a backups/backup_dev_YYYYMMDD_HHMMSS.sql
	@mkdir -p backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	docker compose exec -T db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD pg_dump -U $$POSTGRES_USER rails_app_development' > backups/backup_dev_$$TIMESTAMP.sql; \
	echo "💾 Backup de desarrollo guardado en backups/backup_dev_$$TIMESTAMP.sql"

backup-db-test: ## Volcado de la base de test a backups/backup_test_YYYYMMDD_HHMMSS.sql
	@mkdir -p backups
	@TIMESTAMP=$$(date +%Y%m%d_%H%M%S); \
	docker compose exec -T db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD pg_dump -U $$POSTGRES_USER rails_app_test' > backups/backup_test_$$TIMESTAMP.sql; \
	echo "💾 Backup de test guardado en backups/backup_test_$$TIMESTAMP.sql"

restore-db: ## Restaurar base de desarrollo desde backup (make restore-db FILE=backups/backup_dev_YYYYMMDD_HHMMSS.sql). SOBRESCRIBE la DB actual.
	@test -n "$(FILE)" || (echo "❌ Usar: make restore-db FILE=backups/backup_dev_YYYYMMDD_HHMMSS.sql"; exit 1)
	@test -f "$(FILE)" || (echo "❌ Archivo no encontrado: $(FILE)"; exit 1)
	@echo "⚠️  Se sobrescribirá la base de desarrollo con $(FILE)."
	@docker compose exec -T db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD psql -U $$POSTGRES_USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\''rails_app_development'\'' AND pid <> pg_backend_pid();" -c "DROP DATABASE IF EXISTS rails_app_development;" -c "CREATE DATABASE rails_app_development;"'
	@cat "$(FILE)" | docker compose exec -T -i db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD psql -U $$POSTGRES_USER -d rails_app_development'
	@echo "✅ Base de desarrollo restaurada desde $(FILE)"

restore-db-test: ## Restaurar base de test desde backup (make restore-db-test FILE=backups/backup_test_YYYYMMDD_HHMMSS.sql). SOBRESCRIBE la DB de test.
	@test -n "$(FILE)" || (echo "❌ Usar: make restore-db-test FILE=backups/backup_test_YYYYMMDD_HHMMSS.sql"; exit 1)
	@test -f "$(FILE)" || (echo "❌ Archivo no encontrado: $(FILE)"; exit 1)
	@echo "⚠️  Se sobrescribirá la base de test con $(FILE)."
	@docker compose exec -T db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD psql -U $$POSTGRES_USER -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\''rails_app_test'\'' AND pid <> pg_backend_pid();" -c "DROP DATABASE IF EXISTS rails_app_test;" -c "CREATE DATABASE rails_app_test;"'
	@cat "$(FILE)" | docker compose exec -T -i db sh -c 'PGPASSWORD=$$POSTGRES_PASSWORD psql -U $$POSTGRES_USER -d rails_app_test'
	@echo "✅ Base de test restaurada desde $(FILE)"

audit-gems: ## Audita las gemas de rails. 
	docker compose exec web bundle exec bundle-audit check

install-gems: ## Instala las gemas en Gemfile
	docker compose exec web bundle install

backfill-card-numbers: ## Reprocesa transacciones_raw para completar numero_tarjeta en registros existentes
	@echo "🔄 Iniciando backfill de numero_tarjeta..."
	@echo "⚠️  Este proceso leerá desde Kafka y actualizará solo el campo numero_tarjeta"
	@echo "⏸️  Presiona Ctrl+C para detener cuando hayas actualizado suficientes registros"
	docker compose exec web rails runner "DataBackfillService.backfill_numero_tarjeta"

rebind-karafka-consumer: ## Rebobina el consumer group de Karafka al inicio (para reprocesar mensajes)
	@echo "⏪ Rebobinando consumer group 'enrichment_manager_v3' al inicio..."
	docker compose exec redpanda rpk group seek enrichment_manager_v3 --to start
	@echo "✅ Consumer group rebobinado. Reinicia el worker con: make restart-karafka-worker"
	@echo "⚠️  IMPORTANTE: Modifica temporalmente TransactionsConsumer para permitir actualización de aprobadas"

check-card-numbers: ## Verifica cuántas transacciones tienen numero_tarjeta
	@echo "📊 Verificando estado de numero_tarjeta..."
	docker compose exec web rails runner "total = Transaction.count; con = Transaction.where.not(numero_tarjeta: [nil, '']).count; sin = Transaction.where(numero_tarjeta: [nil, '']).count; puts \"Total: #{total}\"; puts \"✅ Con numero_tarjeta: #{con} (#{(con.to_f / total * 100).round(1)}%)\"; puts \"⚠️  Sin numero_tarjeta: #{sin} (#{(sin.to_f / total * 100).round(1)}%)\""

validate-asyncapi: ## Validar DOCS/asyncapi.yaml con la CLI de AsyncAPI (npx, sin package.json)
	npx --yes @asyncapi/cli validate DOCS/asyncapi.yaml

# --- Recuperación y regeneración de transacciones (desde eventos) ---
recover-transactions-from-clean: ## Recuperar transactions desde el tópico transacciones_clean (recovery desde eventos)
	@echo "🔄 Recuperación desde transacciones_clean..."
	docker compose exec web rails data:recover_from_clean

clean-transactions-only: ## Borrar solo la tabla transactions (sin SourceFile). Útil antes de regenerate-transactions-from-raw.
	@echo "🧹 Borrando transacciones..."
	docker compose exec web rails data:clean_transactions

regenerate-transactions-from-raw: ## Regenerar transactions releyendo transacciones_raw (rewind consumer + Karafka)
	@echo "⏪ Regenerando desde transacciones_raw: 1) borrar transactions 2) rebobinar consumer 3) reiniciar worker"
	$(MAKE) clean-transactions-only
	$(MAKE) rebind-karafka-consumer
	$(MAKE) restart-karafka-worker
	@echo "✅ Worker reiniciado. Las transacciones se repoblarán al consumir transacciones_raw."