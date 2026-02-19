#!/usr/bin/env bash
# Test que Redpanda/Kafka persiste tópicos y mensajes entre reinicios.
# Verifica que el volumen redpanda_data mantiene los datos.
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

TEST_TOPIC="kafka_persistence_test"
TEST_MARKER="KAFKA_PERSISTENCE_TEST_$(date +%s)_$$"

echo "=== Test: Persistencia de Kafka/Redpanda entre reinicios ==="

# 1. Asegurar que Redpanda está corriendo
echo "[1/6] Levantando Redpanda..."
docker compose up -d redpanda

# 2. Esperar a que esté healthy
echo "[2/6] Esperando que Redpanda esté listo..."
for i in $(seq 1 30); do
  if docker compose exec -T redpanda curl -sf http://localhost:9644/v1/status/ready > /dev/null 2>&1; then
    echo "    Redpanda listo."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Redpanda no respondió a tiempo."
    exit 1
  fi
  sleep 2
done

# 3. Crear tópico de prueba y producir mensaje
echo "[3/6] Creando tópico y produciendo mensaje..."
docker compose exec -T redpanda rpk topic create "$TEST_TOPIC" --brokers redpanda:29092 2>/dev/null || true
echo "$TEST_MARKER" | docker compose exec -T redpanda rpk topic produce "$TEST_TOPIC" --brokers redpanda:29092 -f '%v'

# 4. Reiniciar Redpanda
echo "[4/6] Reiniciando Redpanda..."
docker compose restart redpanda

# 5. Esperar a que vuelva a estar healthy
echo "[5/6] Esperando que Redpanda vuelva..."
for i in $(seq 1 30); do
  if docker compose exec -T redpanda curl -sf http://localhost:9644/v1/status/ready > /dev/null 2>&1; then
    echo "    Redpanda listo tras reinicio."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Redpanda no respondió tras reinicio."
    exit 1
  fi
  sleep 2
done

# 6. Consumir y verificar que el mensaje persiste
echo "[6/6] Consumiendo mensaje..."
CONSUMED=$(docker compose exec -T redpanda rpk topic consume "$TEST_TOPIC" --brokers redpanda:29092 -o start -n 1 -f '%v' 2>/dev/null | tr -d '\r')

if echo "$CONSUMED" | grep -q "$TEST_MARKER"; then
  echo ""
  echo "=== OK: El mensaje persiste tras reiniciar Redpanda ==="
  docker compose exec -T redpanda rpk topic delete "$TEST_TOPIC" --brokers redpanda:29092 2>/dev/null || true
  exit 0
else
  echo ""
  echo "=== FAIL: El mensaje NO persiste. Esperado: $TEST_MARKER"
  echo "    Consumido: $CONSUMED"
  exit 1
fi
