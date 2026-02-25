# Diseño: Event Repository Inmutable Append-Only

*Versión: 1.0 | Febrero 2026*

## 1. Objetivo

Un **Event Repository** inmutable y append-only que persista todos los eventos del pipeline Audit-X, permitiendo:

- **Auditoría completa** — Historia reconstruible de todo lo ocurrido.
- **Event Sourcing** — Reconstruir estado desde el stream de eventos.
- **Replay** — Re-procesar eventos para correcciones o nuevas proyecciones.
- **Análisis temporal** — Queries por tiempo, agregado, tipo de evento.

Siguiendo mejores prácticas: **versionado de esquemas**, **upcasting en lectura**, **índice global** y **payload normalizado**.

---

## 2. Event Envelope (estructura estándar)

Cada evento persiste con una envoltura que separa metadatos del contenido:

```
┌─────────────────────────────────────────────────────────────────────┐
│ ENVELOPE (metadata fija, indexada)                                  │
├─────────────────────────────────────────────────────────────────────┤
│ id              UUID v4 único, orden total                           │
│ event_type      string: "transaction.approved", "category_rule.updated" │
│ event_version   int: 1, 2, 3... (versionado de esquema del payload)  │
│ occurred_at     timestamp UTC (momento del evento)                   │
│ aggregate_type  string: "Transaction", "CategoryRule", "SourceFile"  │
│ aggregate_id    string: ID del agregado (event_id, id, etc.)         │
│ stream_id       string: agrupación lógica (ej. "Transaction:abc123") │
│ causation_id    UUID: ID del comando/evento que causó este           │
│ correlation_id  UUID: trazabilidad cross-service                    │
│ metadata        JSON: origen, user_id, request_id, etc.              │
└─────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────┐
│ PAYLOAD (contenido del evento, versionado)                           │
├─────────────────────────────────────────────────────────────────────┤
│ body            JSON: datos del dominio según event_type + version   │
└─────────────────────────────────────────────────────────────────────┘
```

### Campos obligatorios

| Campo           | Tipo     | Descripción                                                        |
|-----------------|----------|--------------------------------------------------------------------|
| `id`            | UUID     | Identificador único; también orden total (o usar `sequence_number`) |
| `event_type`    | string   | `{aggregate}.{action}` (ej. `transaction.approved`)                 |
| `event_version` | int      | Versión del esquema del payload (1, 2, 3…)                         |
| `occurred_at`   | timestamp| Momento en que ocurrió el evento (UTC)                             |
| `aggregate_type`| string   | Tipo del agregado (Transaction, CategoryRule, …)                   |
| `aggregate_id`  | string   | ID del agregado (event_id, id numérico, etc.)                      |
| `stream_id`     | string   | `{aggregate_type}:{aggregate_id}` para queries por stream          |
| `body`          | JSONB    | Payload del evento                                                 |

### Campos opcionales

| Campo           | Tipo   | Uso                                            |
|-----------------|--------|------------------------------------------------|
| `causation_id`  | UUID   | ID del comando/evento que disparó este evento  |
| `correlation_id`| UUID   | Trazabilidad entre servicios                  |
| `metadata`      | JSONB  | `user_id`, `request_id`, `source`, etc.        |

---

## 3. Versionado de esquemas

### Estrategia

- **event_version** = versión del *payload* para ese `event_type`.
- Al cambiar el esquema del payload, se incrementa la versión.
- Los eventos antiguos permanecen intactos (inmutabilidad).

### Convención de versionado

```
event_type: "transaction.approved"
event_version: 1  → payload v1 (categoria, sentimiento, ...)
event_version: 2  → payload v2 (nuevo campo "etiquetas", etc.)
```

### Registro de versiones

Mantener un registro explícito de esquemas por tipo y versión:

```yaml
# config/event_schemas.yml (ejemplo)
transaction.approved:
  1:
    schema: "TransactionApprovedV1"
    deprecated: false
  2:
    schema: "TransactionApprovedV2"
    deprecated: false
    added_fields: ["etiquetas"]
```

---

## 4. Upcasting (migración en lectura)

**Upcasting** = transformar un payload de una versión antigua a la versión actual **en tiempo de lectura**, sin modificar el evento almacenado.

### Flujo

```
Lectura: body (v1) → Upcaster → body (v2) → Aplicación
```

### Implementación

- Un **Upcaster** por cada par `(event_type, from_version → to_version)`.
- Al leer eventos, si `event_version < current_version`, se aplica la cadena de upcasters.

```ruby
# Ejemplo conceptual
class TransactionApprovedUpcaster
  def upcast(body, from_version, to_version)
    return body if from_version >= to_version
    # v1 → v2: añadir campo por defecto
    body["etiquetas"] = [] if from_version == 1 && to_version >= 2
    body
  end
end
```

### Reglas

- Upcasters son **deterministas** y **sin efectos secundarios**.
- Nunca se escribe de vuelta al store (inmutabilidad).
- Si no hay upcaster para una versión, fallar con error explícito (evitar datos corruptos).

---

## 5. Índice global

Para consultas eficientes se necesita un índice global. Opciones:

### 5.1 Índices recomendados (PostgreSQL)

| Índice               | Columnas                              | Uso                                  |
|----------------------|---------------------------------------|--------------------------------------|
| `idx_events_occurred`| `(occurred_at)`                       | Queries temporales                   |
| `idx_events_stream`  | `(stream_id, occurred_at)`            | Stream por agregado                  |
| `idx_events_aggregate`| `(aggregate_type, aggregate_id)`     | Búsqueda por agregado                |
| `idx_events_type`    | `(event_type, occurred_at)`           | Filtro por tipo                      |
| `idx_events_sequence`| `(sequence_number)`                   | Orden total (si se usa)              |
| `idx_events_metadata`| `(metadata)` GIN                      | Búsqueda en metadata (opcional)      |

### 5.2 Orden total

Para garantizar orden total entre eventos:

- **Opción A:** `sequence_number` BIGSERIAL (auto-increment en INSERT).
- **Opción B:** `id` UUID v7 (ordenable por tiempo).
- **Opción C:** `occurred_at + id` para desempate.

Recomendación: `sequence_number` por simplicidad y rendimiento en PostgreSQL.

---

## 6. Payload

### Formato

- **body**: JSONB en PostgreSQL.
- Permite indexación GIN y queries sobre campos internos si se requiere.
- Evitar payloads enormes (>100KB); para blobs usar MinIO y guardar solo la URI en el payload.

### Normalización

- Nombres en `snake_case`.
- Fechas en ISO8601.
- No incluir datos derivables (ej. totales calculables desde otros eventos).

### Ejemplo

```json
{
  "event_id": "abc123",
  "fecha": "2025-02-03T12:00:00Z",
  "monto": 15000.50,
  "categoria": "Supermercado",
  "sub_categoria": "Coto",
  "sentimiento": "Necesario",
  "detalles": "COTO CENCOSUD",
  "origen": "definitivo"
}
```

---

## 7. Almacenamiento

### Opción recomendada: PostgreSQL append-only

| Pros                               | Contras                    |
|------------------------------------|----------------------------|
| Ya en el stack                     | Crecimiento continuo       |
| Transacciones ACID                 | Necesita política de retención/archivo |
| Índices estándar                   |                            |
| Fácil integración con Rails        |                            |

### Esquema de tabla

```sql
CREATE TABLE event_store (
  sequence_number  BIGSERIAL PRIMARY KEY,
  id               UUID NOT NULL UNIQUE,
  event_type       VARCHAR(255) NOT NULL,
  event_version    INT NOT NULL DEFAULT 1,
  occurred_at      TIMESTAMPTZ NOT NULL,
  aggregate_type   VARCHAR(255) NOT NULL,
  aggregate_id     VARCHAR(255) NOT NULL,
  stream_id        VARCHAR(512) NOT NULL,
  causation_id     UUID,
  correlation_id   UUID,
  metadata         JSONB,
  body             JSONB NOT NULL,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_occurred ON event_store (occurred_at);
CREATE INDEX idx_events_stream ON event_store (stream_id, occurred_at);
CREATE INDEX idx_events_aggregate ON event_store (aggregate_type, aggregate_id);
CREATE INDEX idx_events_type ON event_store (event_type, occurred_at);
CREATE UNIQUE INDEX idx_events_id ON event_store (id);
```

### Política de retención (opcional)

- Eventos > N años → archivar a tabla `event_store_archive` o cold storage.
- Mantener índices solo en datos recientes para rendimiento.

---

## 8. Fuentes de eventos

### Eventos a persistir

| Origen            | Tópico / fuente       | event_type ejemplo          |
|-------------------|------------------------|-----------------------------|
| Rails             | domain_events          | transaction.updated, category_rule.created |
| Rails             | transacciones_clean    | transaction.approved        |
| Python            | transacciones_raw      | transaction.ingested        |
| Python            | file_results           | file.processed              |
| Rails             | file_uploaded          | file.uploaded               |

### Estrategia de captura

1. **Consumer dedicado** — Un proceso (Rails o worker) consume todos los tópicos y escribe en `event_store`.
2. **Dual-write** — Donde se publica, también se escribe en el store (más acoplamiento, menor latencia).
3. **CDC desde Kafka** — Kafka como source of truth; un connector escribe en PostgreSQL (si se usa Kafka Connect).

Recomendación: **Consumer dedicado** que subscribe a los tópicos relevantes y persiste en `event_store`. Mantiene el store como capa de persistencia separada y desacoplada.

---

## 9. Integración con arquitectura actual

```
                    ┌──────────────────┐
                    │  Event Repository│
                    │  (PostgreSQL     │
                    │   event_store)   │
                    └────────▲─────────┘
                             │ append
         ┌───────────────────┼───────────────────┐
         │                   │                   │
    ┌────┴────┐        ┌─────┴─────┐       ┌─────┴─────┐
    │ domain_ │        │transacc.  │       │  file_    │
    │ events  │        │ _clean    │       │ results   │
    └────▲────┘        └─────▲─────┘       └─────▲─────┘
         │                   │                   │
    ┌────┴────┐        ┌─────┴─────┐       ┌─────┴─────┐
    │  Rails  │        │   Rails   │       │  Python   │
    │DomainEv.│        │ Publishable│       │  Worker   │
    └─────────┘        └───────────┘       └───────────┘
```

- El **EventStoreConsumer** consume `domain_events`, `transacciones_clean`, `file_results`, `transacciones_raw` (opcional) y `file_uploaded` (opcional).
- Normaliza cada mensaje al envelope estándar.
- Inserta en `event_store` (append-only).

---

## 10. Fases de implementación

### Fase 1 — Fundamento (MVP) ✅

- [x] Crear tabla `event_store` con schema anterior (migración `20260203160000_create_event_store.rb`).
- [x] Consumer que subscribe a `domain_events` y persiste en `event_store` (`EventStoreConsumer`, topic en `karafka.rb`).
- [x] API mínima para leer por `stream_id` o por `occurred_at`: `GET /event_store?stream_id=...` o `?from=...&to=...&limit=100` (requiere login).

### Fase 2 — Ampliación ✅

- [x] Incluir `transacciones_clean`, `file_results` en el consumer (`EventStoreConsumer` ramifica por `topic.name`).
- [x] Versionado: todos los eventos se persisten con `event_version: 1`.
- [x] Consumer group dedicado `event_store` en Karafka (domain_events, transacciones_clean, file_results).
- [x] Registro YAML `config/event_schemas.yml` y servicio `EventSchemasRegistry` (schema_for, current_version, registered?). El consumer guarda `metadata.schema` y `metadata.schema_deprecated` cuando el event_type está registrado.
- [x] Tests TDD: `StoredEventTest`, `EventStoreConsumerTest`, `EventStoreControllerTest`, `EventSchemasRegistryTest`.

### Fase 3 — Versionado y upcasting ✅

- [x] Primer cambio de esquema con nueva versión (`transaction.approved` v2 en `event_schemas.yml`, campo `etiquetas`).
- [x] Implementar upcaster(s) y hook en el reader (`EventStore::Upcasters::TransactionApprovedUpcaster`, `UpcasterRegistry`, `ReaderWithUpcast`; controller usa reader en `event_to_json`).
- [x] Tests de upcasting (`TransactionApprovedUpcasterTest`, `UpcasterRegistryTest`, `ReaderWithUpcastTest`).

### Fase 4 — Operación

- [ ] Política de retención/archivo.
- [ ] Monitoring y alertas sobre lag del consumer.
- [ ] Documentación de runbook.

---

## 11. Referencias

- [Event Sourcing (Martin Fowler)](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Versioning in an Event Sourced System (Greg Young)](https://leanpub.com/esversioning)
- [Event Envelope pattern](https://www.enterpriseintegrationpatterns.com/patterns/messaging/EnvelopeWrapper.html)
