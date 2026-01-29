# 🔄 Backfill de numero_tarjeta

Guía para completar el campo `numero_tarjeta` en transacciones existentes que fueron creadas antes de agregar este campo.

## 📋 Situación

Las transacciones creadas antes de agregar el campo `numero_tarjeta` no tienen este dato. Los mensajes originales en Kafka `transacciones_raw` sí contienen esta información, así que podemos reprocesarlos.

---

## 🎯 Opción 1: Script Directo desde Kafka (Recomendado)

**Ventajas:**
- ✅ No requiere modificar el consumer
- ✅ Más seguro (solo actualiza el campo necesario)
- ✅ Puedes detenerlo cuando quieras (Ctrl+C)
- ✅ Muestra progreso en tiempo real

**Pasos:**

```bash
# Ejecutar el backfill
make backfill-card-numbers
```

El script:
1. Se conecta a Kafka y lee desde el inicio del tópico `transacciones_raw`
2. Para cada mensaje, busca la transacción por `event_id`
3. Si la transacción existe y tiene `numero_tarjeta` en el mensaje pero no en la DB, lo actualiza
4. Muestra progreso cada 1000 mensajes

**Detener el proceso:**
- Presiona `Ctrl+C` cuando hayas actualizado suficientes registros

---

## 🎯 Opción 2: Rebobinar Consumer Group (Alternativa)

**Ventajas:**
- ✅ Usa el consumer existente
- ✅ Procesa todos los mensajes automáticamente

**Desventajas:**
- ⚠️ Requiere modificar temporalmente el consumer
- ⚠️ Puede sobreescribir otros campos si no tienes cuidado

**Pasos:**

1. **Hacer backup del consumer original:**
   ```bash
   docker compose exec web cp app/consumers/transactions_consumer.rb app/consumers/transactions_consumer.rb.backup
   ```

2. **Usar la versión de backfill:**
   ```bash
   docker compose exec web cp app/consumers/transactions_consumer_backfill.rb app/consumers/transactions_consumer.rb
   ```

3. **Rebobinar el consumer group:**
   ```bash
   make rebind-karafka-consumer
   ```

4. **Reiniciar el worker:**
   ```bash
   make restart-karafka-worker
   ```

5. **Monitorear los logs:**
   ```bash
   docker compose logs -f karafka_server
   ```

6. **Cuando termine, restaurar el consumer original:**
   ```bash
   docker compose exec web cp app/consumers/transactions_consumer.rb.backup app/consumers/transactions_consumer.rb
   docker compose restart karafka_server
   ```

---

## 🔍 Verificar Resultados

Después de ejecutar cualquiera de las opciones, verifica cuántas transacciones se actualizaron:

```bash
# En la consola de Rails
make shell-web

# Luego en la consola:
Transaction.where.not(numero_tarjeta: [nil, '']).count
Transaction.where(numero_tarjeta: [nil, '']).count
```

---

## ⚠️ Notas Importantes

1. **Retención de Kafka**: Si los mensajes ya fueron eliminados de Kafka (por retención), la Opción 1 no funcionará. En ese caso, necesitarías re-procesar los archivos originales desde S3.

2. **Transacciones Aprobadas**: 
   - La Opción 1 actualiza también transacciones aprobadas (solo el campo `numero_tarjeta`)
   - La Opción 2 con el consumer modificado también actualiza aprobadas

3. **Idempotencia**: Ambos métodos son idempotentes - puedes ejecutarlos múltiples veces sin problemas.

4. **Performance**: 
   - La Opción 1 procesa mensaje por mensaje (más lento pero más seguro)
   - La Opción 2 usa el consumer normal (más rápido)

---

## 🐛 Troubleshooting

**Error: "No se puede conectar a Kafka"**
- Verifica que Redpanda esté corriendo: `docker compose ps redpanda`
- Verifica la variable `KAFKA_SERVERS` en el `.env`

**Error: "rdkafka no encontrado"**
- Karafka incluye rdkafka, pero si falla, verifica: `docker compose exec web bundle list | grep rdkafka`

**No se actualizan transacciones:**
- Verifica que los mensajes en Kafka tengan el campo `numero_tarjeta`
- Verifica que las transacciones en la DB tengan `event_id` que coincida con los mensajes

---

**Última actualización:** Enero 2026
