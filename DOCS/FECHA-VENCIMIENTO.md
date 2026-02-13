# Fecha de vencimiento y origen (Opción B)

## Decisión de diseño

Se adoptó la **Opción B** para distinguir cargas parciales (Excel/CSV/Sheets) de resúmenes cerrados (PDF):

- **fecha_vencimiento:** Fecha de cierre o vencimiento del resumen. Opcional. Permite agrupar transacciones por período de facturación.
- **origen:** `parcial` (cargas intermedias) o `definitivo` (resúmenes cerrados). Default: `definitivo`.

## Separación estratégico / táctico

- **Estratégico (Grafana):** Filtros por `fecha_vencimiento` (tag) y `origen` (field) permiten separar métricas por tipo de carga y período de cierre.
- **Táctico (Rails/Python):** El campo `origen` se asigna automáticamente: PDF → `definitivo`, Excel/CSV/Sheets → `parcial`.

## Uso de origen en Grafana

- **origen = definitivo:** Resúmenes cerrados (PDF de banco). Datos finales del período.
- **origen = parcial:** Cargas intermedias. Pueden duplicarse cuando llegue el resumen definitivo (event_id previene duplicados reales).

## Flujo de datos

1. **UI:** Campo opcional "Fecha de vencimiento" en cargas Excel/CSV/PDF.
2. **Python:** PDF extractors extraen `fecha_vencimiento` cuando el documento la incluye; Excel/CSV la reciben desde params.
3. **Rails:** `TransactionsConsumer` persiste ambos campos; `Publishable` los incluye en `transacciones_clean`.
4. **Telegraf:** Tag `fecha_vencimiento`, field `origen` en InfluxDB.
