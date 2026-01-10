


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