


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


# Google Sheet

1.1 Crear el Proyecto y Habilitar APIs
Entra a Google Cloud Console.
Arriba a la izquierda, haz clic en el selector de proyectos y selecciona "New Project". Ponle un nombre como Personal-Observability.
En la barra de búsqueda superior, busca "Google Sheets API" y haz clic en Enable.
Haz lo mismo buscando "Google Drive API" y dale a Enable (necesaria para que el script pueda "listar" y encontrar los archivos por nombre).

1.2 Crear la Cuenta de Servicio
En el menú lateral izquierdo, ve a APIs & Services > Credentials.
Haz clic en el botón superior "+ Create Credentials" y elige "Service Account".
Ponle un nombre (ej. pipeline-ingestor). Haz clic en Create and Continue.
En el paso de "Roles", puedes dejarlo en blanco o ponerle el rol de Viewer. Haz clic en Done.

1.3 Generar la Llave (JSON)
Verás tu nueva cuenta creada en la lista de "Service Accounts". Haz clic en su email (el enlace azul).
Ve a la pestaña "Keys" (arriba).
Haz clic en "Add Key" > "Create new key".
Elige el formato JSON y dale a Create.
Se descargará automáticamente un archivo en tu PC. Renómbralo como credentials.json y muévelo a la carpeta ingestion/ de tu proyecto en WSL.

**1.4 Vincular la Cuenta con tu Hoja de Cálculo (Paso Crítico)**
Este es el paso donde la mayoría falla. Tu script no tiene tus contraseñas, por lo que la hoja de cálculo debe "invitar" a la cuenta de servicio como si fuera un usuario real.
Abre el archivo credentials.json que descargaste y busca el campo "client_email". Verás algo como pipeline-ingestor@tu-proyecto.iam.gserviceaccount.com. Cópialo.
Abre tu Google Sheet de gastos en el navegador.
Haz clic en el botón azul "Share" (Compartir) arriba a la derecha.
Pega el email de la cuenta de servicio y asegúrate de que tenga permisos de Editor (o Viewer si solo vas a leer).
Desmarca "Notify people" y dale a Send.


1.5 Verificar Seguridad
En tu terminal de WSL, confirma que el archivo esté en su lugar:
bash
ls ingestion/credentials.json
Usa el código con precaución.

Y añade el archivo a tu .gitignore para no exponerlo en Git:
bash
echo "ingestion/credentials.json" >> .gitignore
Usa el código con precaución.

Ahora tu script de Python podrá usar ese archivo para "hacerse pasar" por la cuenta de servicio y leer tus datos sin necesidad de intervención humana ni ventanas de login de navegador. Documentación de gspread.

markdown
Para avanzar con la aplicación **Rails** como motor de enriquecimiento en 2026, el flujo de trabajo se centrará en transformar los datos crudos de Kafka en información estructurada (por ejemplo, categorizar un gasto de "Supermercado" o "Suscripción") antes de enviarlos a InfluxDB.

Aquí tienes los pasos para configurar esta capa de enriquecimiento:

### 1. Configuración de Karafka (Consumidor)
En 2026, **Karafka** es el estándar para integrar Kafka con Rails de forma eficiente. En tu archivo `karafka.rb`, definiremos cómo escuchar el tópico que creamos en Python:

```ruby
# karafka.rb
class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV['KAFKA_SERVERS'] }
    config.client_id = 'web_enrichment_app'
  end

  routes.draw do
    topic :transacciones_raw do
      consumer TransactionsConsumer
    end
  end
end
```

### 2. El Consumer de Enriquecimiento
Aquí es donde ocurre la "magia". El consumidor recibirá el JSON de Python, buscará si existe en PostgreSQL (evitando duplicados) y aplicará reglas de categorización.

```ruby
# app/consumers/transactions_consumer.rb
class TransactionsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload
      
      # 1. Idempotencia: Buscar o crear por event_id
      transaction = Transaction.find_or_initialize_by(event_id: data['event_id'])
      
      # 2. Enriquecimiento: Lógica de categorías (puedes usar reglas o IA)
      transaction.assign_attributes(
        fecha: data['fecha_transaccion'],
        monto: data['monto'],
        moneda: data['moneda'],
        descripcion: data['detalles'],
        categoria: CategorizerService.guess(data['detalles']), # Servicio personalizado
        red: data['red']
      )

      if transaction.save
        # 3. Notificar a InfluxDB una vez enriquecido
        InfluxWriterService.write_point(transaction)
      end
    end
  end
end
```

### 3. Servicio de Escritura en InfluxDB
Usaremos la gema `influxdb-client` para enviar el dato final a tus dashboards de Grafana.

```ruby
# app/services/influx_writer_service.rb
class InfluxWriterService
  def self.write_point(transaction)
    client = InfluxDB2::Client.new(
      ENV['INFLUX_URL'], 
      ENV['INFLUX_TOKEN'],
      precision: InfluxDB2::WritePrecision::SECOND
    )
    
    write_api = client.create_write_api
    
    point = InfluxDB2::Point.new(name: 'consumos')
      .add_tag('categoria', transaction.categoria)
      .add_tag('moneda', transaction.moneda)
      .add_tag('red', transaction.red)
      .add_field('valor', transaction.monto.to_f)
      .time(transaction.fecha.to_time.to_i)

    write_api.write(data: point, bucket: ENV['INFLUX_BUCKET'], org: ENV['INFLUX_ORG'])
  end
end
```

### 4. Ventajas de este Refactor en Rails
*   **PostgreSQL como Buffer:** Mantener las transacciones en Postgres te permite crear una interfaz web en Rails (puerto 3000) para corregir manualmente categorías mal asignadas.
*   **Actualización en Cascada:** Si corriges una categoría en la web, puedes disparar un evento que actualice InfluxDB una vez enriquecido.
*   **Escalabilidad:** Al usar el puerto `29092` interno en Docker, tu worker de Karafka procesará miles de registros por segundo sin latencia.

### Próximo Paso Sugerido
Para que el sistema sea funcional en tu entorno Docker actual, asegúrate de correr las migraciones en el contenedor de Rails:
`docker compose exec web bundle exec rails db:prepare`

Y luego inicia el worker para empezar a recibir los datos de tu script de Python:
`docker compose up karafka_server`