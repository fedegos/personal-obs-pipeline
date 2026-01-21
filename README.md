# 💰 Audit-X: Centro de Operaciones 2026

Utiliza este archivo como tu panel de control. Si tienes la extensión **Runme** instalada en VS Code, verás botones de "Run" en cada bloque.

## 🚀 Gestión de Infraestructura

Levanta o detiene el pipeline completo de servicios (Docker).

```sh {"name":"up-all"}
make up
```

```sh {"name":"down-all"}
make down-volumes
```

## 📊 Observabilidad de Datos

Comandos para verificar la salud de los flujos de información en tiempo real.

**Estado de Redpanda (Kafka):**

```sh {"name":"status-kafka"}
make inspect-kafka
```

**Verificación de Ingesta en InfluxDB:**

```sh {"name":"status-influx"}
make inspect-influx
```

## ⏪ Reprocesamiento y Reset

Utiliza estos comandos cuando modifiques las reglas de categorización o el parser de Telegraf.

```sh {"name":"reprocess-all"}
make reprocess-all
```

```sh {"name":"reset-total"}
make reset-history
```

## 🛠️ Herramientas de Desarrollo

Acceso directo a la consola de Rails y backups de la inteligencia del sistema.

```sh {"name":"rails-console"}
make shell-web
```

```sh {"name":"backup-rules"}
make backup-rules
```

---

## 🌅 Morning Checkup (Diagnóstico Diario)

Ejecuta estos tres bloques cada mañana para asegurar que el pipeline de datos está saludable antes de empezar a trabajar.

### 1. Estado de los Contenedores

Verifica que los 10 servicios (Redpanda, Influx, Rails, etc.) estén en estado `running` y sin reinicios constantes.

```sh {"name":"check-containers"}
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}"
```

### 2. Flujo de Mensajes en Kafka

Este comando verifica si hay "Lag" en Telegraf. Si el **LAG** es 0, significa que todos los gastos procesados en Rails ya llegaron a la base de datos.

```sh {"name":"check-kafka-lag"}
docker compose exec redpanda rpk group describe telegraf_metrics_group_v4 | grep -E "TOPIC|transacciones_clean"
```

### 3. Latido de Datos en InfluxDB

Verifica que hayamos recibido transacciones en el último mes. Si la tabla está vacía, el problema podría estar en el parser de Telegraf o en el worker de Rails.

```sh {"name":"check-influx-heartbeat"}
docker compose exec influxdb influx query \
  'from(bucket: "'$INFLUX_BUCKET'") 
   |> range(start: -1mo) 
   |> filter(fn: (r) => r._measurement == "kafka_consumer")
   |> count()' \
  --org "$INFLUX_ORG" --token "$INFLUX_TOKEN"
```

**Tip de 2026:** Puedes mantener este archivo abierto en una pestaña lateral de VS Code (modo Runme Dashboard) para operar el sistema sin salir de tu editor de código.
