# Audit-X Operations 2026

ifneq ("$(wildcard .env)","")
    include .env
    export $(shell sed 's/=.*//' .env)
endif

.PHONY: clean-db clean-influx clean-kafka reset-history help

.DEFAULT_GOAL := help

help: ## Muestra esta ayuda
	@echo "-----------------------------------------------------------------------"
	@echo "Audit-X DevOps Commands (2026)"
	@echo "-----------------------------------------------------------------------"
	@grep -Eh '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-25s\033[0m %s\n", $$1, $$2}'


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

logs: ## Ver logs de todos los servicios con timestamps
	docker compose logs -f -t

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

test: ## Correr tests de Rails
	docker compose exec web bundle exec rspec

security-check: ## Verificar vulnerabilidades en gemas (Seguridad 2026)
	docker compose exec web bundle exec bundle-audit update
	docker compose exec web bundle exec bundle-audit check
	docker compose exec web bundle exec brakeman

lint: ## Linting de Ruby (Estilo de código)
	docker compose exec web bundle exec rubocop -A


setup: up ## Preparar todo el sistema desde cero
	docker compose exec web bundle install
	docker compose exec web rails db:prepare
	docker compose exec web rails db:seed
	@echo "✅ Sistema listo en http://localhost:3000"

backup-rules: ## Exportar las CategoryRules a un archivo YAML
	docker compose exec web rails runner "File.write('db/category_rules_backup.yml', CategoryRule.all.to_yaml)"
	@echo "💾 Reglas exportadas a db/category_rules_backup.yml"

