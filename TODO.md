Contexto: El stack está en Docker (Redpanda, Influx, Grafana). Python ya sabe generar hashes únicos.
Pendiente inmediato:
Crear el archivo datos_banco.xlsx de prueba para que Python tenga qué leer.
Configurar el karafka.rb en Rails para que apunte al servidor localhost:9092.
Definir los callbacks en el modelo Transaction.rb para que, al marcar como enriquecido, envíe el dato a InfluxDB.
