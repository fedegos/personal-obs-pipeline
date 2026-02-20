# Dashboards Grafana (versionados)

Los JSON de esta carpeta se cargan automaticamente al iniciar `grafana`.

- Data source esperado: `influxdb-main`
- Folder en UI: `Audit-X` (definido en `grafana/provisioning/dashboards/dashboards.yml`)

## Catalogo actual

- `auditx-overview.json` - Vista general operativa.
- `auditx-year-evolution.json` - Evolucion anual (estrategico).
- `auditx-variations.json` - Variaciones y desvíos (analitico).
- `auditx-tactical-operational.json` - Tablero tactico operativo (parcial vs definitivo).
- `auditx-day-of-month-heatmap.json` - Estacionalidad por dia del mes.
- `auditx-accumulated-kpis.json` - KPIs acumulados MTD/QTD/YTD.

## Convenciones recomendadas

- Usar `uid` estable para no duplicar dashboards.
- Usar unidades monetarias `currency:ARS`.
- Mantener variables comunes cuando aplique: `origen`, `fecha_vencimiento`, `red`, `numero_tarjeta`.
- Recordar el contrato Flux:
  - tags: `event_id`, `moneda`, `red`, `fecha_vencimiento`
  - fields: `monto`, `categoria`, `sub_categoria`, `sentimiento`, `origen`, `numero_tarjeta`, etc.

## Flujo de trabajo

1. Editar dashboard en Grafana o en JSON.
2. Guardar/exportar el JSON en esta carpeta.
3. Reiniciar Grafana (`make restart-grafana`) para validar provisioning.
