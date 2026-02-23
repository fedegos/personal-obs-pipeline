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
- `auditx-sentiment-analysis.json` - Análisis por sentimiento (evolución, rankings, KPIs).

## Convenciones recomendadas

- Usar `uid` estable para no duplicar dashboards.
- Usar unidades monetarias `currency:ARS` para montos.
- Usar `graphTooltip: 1` para tooltips compartidos (crosshair).
- Etiquetas inteligibles: usar `displayName` para `_value`/Value (ej. "Gastos acumulados (ARS)", "Aumento (ARS)") y columnas técnicas (categoria → Categoría, actual → Últimos 30 días). Nunca mostrar "_value" en ejes o tablas.
- Evitar etiquetas que se encimen: `xTickLabelRotation: -45` en barcharts cuando hay muchas categorías; ordenar día del mes con padding ("01".."31") para sort correcto.
- Jerarquía categoría/subcategoría: manejar `sub_categoria` vacía (`if exists r.sub_categoria and r.sub_categoria != "" then ... else r.categoria`).
- Mantener variables comunes cuando aplique: `origen`, `fecha_vencimiento`, `red`, `numero_tarjeta`.
- Descripciones: cada dashboard debe tener `description` con propósito y cómo usarlo para análisis/decisiones.
- Leyenda con totales: en barcharts/bargauges, usar `legend.calcs: ["sum"]` para mostrar totales.
- Recordar el contrato Flux (Telegraf json_v2):
   - tags: `event_id`, `moneda`, `red`, `fecha_vencimiento`
   - fields: `monto`, `categoria`, `sub_categoria`, `sentimiento`, `origen`, `numero_tarjeta`, etc.

## Flujo de trabajo

1. Editar dashboard en Grafana o en JSON.
2. Guardar/exportar el JSON en esta carpeta.
3. Reiniciar Grafana (`make restart-grafana`) para validar provisioning.
