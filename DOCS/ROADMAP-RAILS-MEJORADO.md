# Arquitectura de Pipeline Financiero 2026: Flujo de Aprobación Manual

Este sistema garantiza que ninguna transacción llegue a tus métricas de Grafana sin antes haber sido revisada y categorizada manualmente en una interfaz web.

---

### 1. Ingesta (Python)
El script extrae datos de archivos bancarios y los publica en el tópico `transacciones_raw`.

```python
# ingestion-engine/main.py
import pandas as pd
import json
from kafka import KafkaProducer

def json_serial(obj):
    if isinstance(obj, (pd.Timestamp)): return obj.isoformat()
    raise TypeError(f"Type {type(obj)} not serializable")

producer = KafkaProducer(
    bootstrap_servers='localhost:9092',
    value_serializer=lambda v: json.dumps(v, default=json_serial).encode('utf-8')
)

# ... lógica de extracción (Amex, Visa) ...
# df['event_id'] se genera mediante un hash determinista
for _, row in df.iterrows():
    producer.send('transacciones_raw', key=row['event_id'].encode(), value=row.to_dict())
```

---

### 2. Enriquecimiento y Cuarentena (Rails 7 + Karafka)

#### Modelo y Base de Datos
```ruby
# db/migrate/20260110_create_transactions.rb
create_table :transactions do |t|
  t.string :event_id, null: false, index: { unique: true }
  t.datetime :fecha
  t.decimal :monto, precision: 15, scale: 2
  t.string :moneda
  t.string :detalles
  t.string :categoria
  t.string :sentimiento # Ej: Necesario, Deseo, Inversión
  t.string :red
  t.boolean :aprobado, default: false, index: true
  t.timestamps
end
```

#### Consumidor de Ingesta (Karafka)
```ruby
# app/consumers/transactions_consumer.rb
class TransactionsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload
      transaction = Transaction.find_or_initialize_by(event_id: data['event_id'])
      
      unless transaction.aprobado?
        transaction.assign_attributes(
          fecha: data['fecha_transaccion'], monto: data['monto'],
          moneda: data['moneda'], detalles: data['detalles'], red: data['red'],
          categoria: CategorizerService.guess(data['detalles']) # Sugerencia automática
        )
        transaction.save
      end
    end
  end
end
```

#### Interfaz de Aprobación (Controlador y Vista)
```ruby
# app/controllers/transactions_controller.rb
def approve
  @transaction = Transaction.find(params[:id])
  if @transaction.update(transaction_params.merge(aprobado: true))
    # RECIÉN AQUÍ SE PUBLICA EN EL TÓPICO CLEAN
    Karafka.producer.produce_async(
      topic: 'transacciones_clean',
      payload: @transaction.to_json(except: [:id, :aprobado, :created_at, :updated_at]),
      key: @transaction.event_id
    )
    redirect_to transactions_path, notice: "Enviado a InfluxDB"
  end
end
```

```html
<!-- app/views/transactions/index.html.erb -->
<table>
  <% @pending.each do |t| %>
    <tr>
      <td><%= t.detalles %></td>
      <td>
        <%= form_with model: t, url: approve_transaction_path(t), method: :patch do |f| %>
          <%= f.text_field :categoria %>
          <%= f.select :sentimiento, ['Necesario', 'Deseo', 'Inversión'] %>
          <%= f.submit "Aprobar" %>
        <% end %>
      </td>
    </tr>
  <% end %>
</table>
```

---

### 3. Conector de Métricas (Telegraf)
Telegraf escucha el tópico limpio y lo vuelca en InfluxDB de forma eficiente.

```toml
# telegraf.conf
[[inputs.kafka_consumer]]
  brokers = ["redpanda:29092"]
  topics = ["transacciones_clean"]
  data_format = "json"
  tag_keys = ["categoria", "moneda", "red", "sentimiento"]

[[outputs.influxdb_v2]]
  urls = ["http://influxdb:8086"]
  token = "token_secreto_2026"
  organization = "mi_org"
  bucket = "finanzas"
```

---

### 4. Infraestructura (Docker Compose)
Configuración optimizada con healthchecks y redes aisladas.

```yaml
services:
  redpanda:
    image: redpandadata/redpanda:latest
    command: >
      redpanda start --overprovisioned --smp 1 --memory 1G
      --kafka-addr INTERNAL://0.0.0.0:29092,EXTERNAL://0.0.0.0:9092
      --advertise-kafka-addr INTERNAL://redpanda:29092,EXTERNAL://localhost:9092
    ports:
      - "9092:9092"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9644/v1/status/ready"]

  telegraf:
    image: telegraf:latest
    depends_on:
      redpanda: { condition: service_healthy }
    volumes:
      - ./telegraf.conf:/etc/telegraf/telegraf.conf:ro

  web:
    build: ./web-enrichment-app
    ports:
      - "3000:3000"
    environment:
      KAFKA_SERVERS: redpanda:29092
    depends_on:
      redpanda: { condition: service_healthy }

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
```

---

### Resumen del Flujo de Trabajo
1. **Ejecutas Python**: Tus gastos bancarios aparecen en la web de Rails (`localhost:3000`).
2. **Revisas**: Grafana (`localhost:3001`) sigue vacío. Clasificas un gasto como "Inversión".
3. **Aprobas**: Al presionar el botón, el dato viaja por Kafka Clean, Telegraf lo procesa y **Grafana se actualiza** con datos verificados.


## Generar el Scaffolding de Transacciones
Ejecuta este comando clave. Esto lo debes ejecutar DENTRO del contenedor web:
bash
docker compose exec web rails generate scaffold Transaction \
  event_id:string:uniq fecha:datetime monto:decimal:precision_15,scale_2 \
  moneda:string detalles:string categoria:string sentimiento:string red:string \
  aprobado:boolean:default_false


Este comando hace varias cosas automáticamente:
- Crea el archivo app/models/transaction.rb.
- Crea el archivo de migración (db/migrate/..._create_transactions.rb).
- Crea el controlador (app/controllers/transactions_controller.rb) con todas las acciones CRUD básicas.
- Crea las vistas (app/views/transactions/...) para listar, ver, crear y editar.
- Genera las rutas (config/routes.rb) automáticamente.

3. Aplicar la Migración
Aplica los cambios a tu base de datos PostgreSQL:
- bash
- docker compose exec web rails db:migrate

4. Ajustar Rutas para el Flujo de Aprobación
Ahora, edita config/routes.rb para reemplazar las rutas resources :transactions que generó el scaffold con las rutas específicas que diseñamos para tu flujo de aprobación manual:

```ruby
# config/routes.rb

Rails.application.routes.draw do
  # Eliminar o comentar: resources :transactions

  # Ruta principal que muestra el listado de pendientes
  get 'transactions', to: 'transactions#index', as: 'transactions'

  # Ruta PATCH para enviar la aprobación y publicar en Kafka
  patch 'transactions/:id/approve', to: 'transactions#approve', as: 'approve_transaction'
  
  # Define tu ruta raíz si lo deseas
  # root 'transactions#index'
end
```

## Configurar Controladores y Vistas
El scaffold generó la base, pero ahora debes editar los archivos app/controllers/transactions_controller.rb y app/views/transactions/index.html.erb con el código exacto de la respuesta anterior, ya que el scaffold por defecto no incluye la lógica de Kafka ni el botón de aprobación.