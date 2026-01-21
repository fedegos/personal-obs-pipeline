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

## 👤 Gestión de Usuarios

Utiliza este bloque para dar de alta nuevos usuarios de forma segura. Al hacer clic en **Run**, el sistema te solicitará el Email y el Password.

```sh {"name":"create-user","promptEnv":"true"}
# Runme solicitará estas variables automáticamente
export EMAIL_USER
export PASSWORD_USER

docker compose exec -T web rails runner "
user = User.new(email: '$EMAIL_USER', password: '$PASSWORD_USER', password_confirmation: '$PASSWORD_USER')
if user.save
  puts '✅ Usuario creado exitosamente: ' + user.email
else
  puts '❌ Error al crear usuario: ' + user.errors.full_messages.join(', ')
end"
```

### Verificar usuarios actuales

```sh {"name":"list-users"}

docker compose exec -T web rails runner "User.all.each { |u| puts u.email }"
```

## 🌅 Morning Checkup (Diagnóstico Diario)

Ejecuta estos tres bloques cada mañana para asegurar que el pipeline de datos está saludable antes de empezar a trabajar.

### 1. Estado de los Contenedores

Verifica que los 10 servicios (Redpanda, Influx, Rails, etc.) estén en estado `running` y sin reinicios constantes.

```sh {"name":"check-containers"}
# Colorea en verde 'running' o 'healthy' y en rojo 'exit' o 'unhealthy'
docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Health}}" | \
grep -E --color=always "running|healthy|Status|$"
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

### 4. 🌅 Morning Checkup Pro

Verifica los contenedores y el lag de Kafka.

```sh {"name":"morning-checkup-pro"}
# Definición de colores 2026
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🔍 Verificando Contenedores..."
if docker compose ps | grep -q "unhealthy"; then
    echo -e "${RED}❌ ALERTA: Hay servicios con problemas de salud${NC}"
else
    echo -e "${GREEN}✅ Todos los servicios están saludables${NC}"
fi

echo -e "\n🔍 Verificando Lag de Kafka..."
LAG=$(docker compose exec redpanda rpk group describe telegraf_metrics_group_v4 | grep "transacciones_clean" | awk '{print $6}')
if [ "$LAG" -eq "0" ]; then
    echo -e "${GREEN}✅ Kafka sincronizado (Lag: 0)${NC}"
else
    echo -e "${RED}⚠️  Atención: Hay un lag de $LAG mensajes${NC}"
fi
```

**Tip de 2026:** Puedes mantener este archivo abierto en una pestaña lateral de VS Code (modo Runme Dashboard) para operar el sistema sin salir de tu editor de código.
