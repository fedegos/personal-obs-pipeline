


# Rails

## Crear Modelo de datos
```bash
bin/rails generate scaffold Transaction event_id:string:index amount:decimal merchant:string category:string necessity:string mood:string enriched:boolean
bin/rails db:create db:migrate
```

- [ ] Revisar el modelo de datos antes de crear


# Fase 4: Conexión Final a InfluxDB
Una vez que etiquetas una transacción en Rails y le das a "Guardar":
Rails marca la transacción como enriched: true.
Rails envía un nuevo mensaje al topic de Kafka transacciones_enriched.
Un pequeño consumidor final (puede ser un script de Python o un plugin de Influx) toma ese dato y lo guarda en InfluxDB.
