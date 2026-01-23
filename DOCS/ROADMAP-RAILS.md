# Sistema de Enriquecimiento de Gastos (Rails + Karafka + Telegraf)

Esta aplicación consume transacciones crudas de Kafka, las persiste en PostgreSQL para permitir la edición manual (categorías/sentimientos) y publica los datos enriquecidos en un tópico limpio.

### 1. Modelo de Datos (PostgreSQL)
Necesitamos una tabla que guarde la transacción y sus metadatos de enriquecimiento.

```ruby
# db/migrate/20260110_create_transactions.rb
class CreateTransactions < ActiveRecord::Migration[7.1]
  def change
    create_table :transactions do |t|
      t.string :event_id, null: false, index: { unique: true }
      t.datetime :fecha
      t.decimal :monto, precision: 15, scale: 2
      t.string :moneda
      t.string :detalles
      t.string :categoria
      t.string :sentimiento # Ej: 'Necesario', 'Deseo', 'Inversión'
      t.string :red
      t.timestamps
    end
  end
end
```

### 2. Configuración de Karafka (Consumidor y Productor)
Rails escucha el tópico `transacciones_raw` y produce en `transacciones_clean`.

```ruby
# karafka.rb
class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV['KAFKA_SERVERS'] }
    config.client_id = 'enrichment_manager'
  end

  routes.draw do
    topic :transacciones_raw do
      consumer TransactionsConsumer
    end
  end
end
```

### 3. El Consumer: Enriquecedor y Puente
El worker procesa el evento, lo guarda y emite el evento "limpio".

```ruby
# app/consumers/transactions_consumer.rb
class TransactionsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload
      
      # Persistencia e Idempotencia
      transaction = Transaction.find_or_initialize_by(event_id: data['event_id'])
      
      transaction.assign_attributes(
        fecha: data['fecha_transaccion'],
        monto: data['monto'],
        moneda: data['moneda'],
        detalles: data['detalles'],
        red: data['red'],
        # Enriquecimiento automático inicial
        categoria: CategorizerService.guess(data['detalles']),
        sentimiento: SentimentService.analyze(data['detalles'])
      )

      if transaction.save
        publish_clean_event(transaction)
      end
    end
  end

  private

  def publish_clean_event(transaction)
    Karafka.producer.produce_async(
      topic: 'transacciones_clean',
      payload: transaction.to_json(only: [:event_id, :fecha, :monto, :moneda, :detalles, :categoria, :sentimiento, :red]),
      key: transaction.event_id
    )
  end
end
```

### 4. Gestión Web (UI)
Para que puedas corregir categorías o sentimientos desde el navegador (Puerto 3000).

```ruby
# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  def index
    @transactions = Transaction.order(fecha: :desc).page(params[:page])
  end

  def update
    @transaction = Transaction.find(params[:id])
    if @transaction.update(transaction_params)
      # Al actualizar manualmente, republicamos en Kafka para corregir InfluxDB/Grafana
      Karafka.producer.produce_async(
        topic: 'transacciones_clean',
        payload: @transaction.to_json,
        key: @transaction.event_id
      )
      redirect_to transactions_path, notice: 'Enriquecimiento actualizado.'
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:categoria, :sentimiento)
  end
end
```

### 5. Configuración de Telegraf (El Conector)
Telegraf escucha el tópico `transacciones_clean` y lo inyecta en InfluxDB automáticamente. Este archivo debe ir en la raíz para ser mapeado en Docker.

```toml
# telegraf.conf
[[inputs.kafka_consumer]]
  brokers = ["redpanda:29092"]
  topics = ["transacciones_clean"]
  data_format = "json"
  tag_keys = ["categoria", "moneda", "red", "sentimiento"]
  json_string_fields = ["detalles"]
  json_name_key = "event_id" # Opcional

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "token_secreto_2026"
  organization = "mi_org"
  bucket = "finanzas"
```

### 6. Actualización del Docker Compose
Agregamos el servicio Telegraf para cerrar el círculo.

```yaml
  telegraf:
    image: telegraf:latest
    container_name: telegraf_connector
    depends_on:
      redpanda:
        condition: service_healthy
      influxdb:
        condition: service_started
    volumes:
      - ./telegraf.conf:/etc/telegraf/telegraf.conf:ro
    networks:
      - pipeline_net
```

### Ventajas de este patrón:
1. **Idempotencia real**: Si procesas el mismo CSV dos veces, Rails detecta el `event_id` existente y no genera ruido en InfluxDB.
2. **Corrección retroactiva**: Si cambias una categoría en la web de Rails, el evento se vuelve a publicar y Telegraf/InfluxDB actualizan el punto (ya que tienen el mismo ID/Timestamp).
3. **Escalabilidad**: Rails solo hace lógica de negocio (enriquecer). El movimiento pesado de datos a la DB de métricas lo hace Telegraf, que es mucho más eficiente en memoria.
