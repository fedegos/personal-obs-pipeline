# Dashboards Grafana (versionados)

Coloca aqui los JSON exportados desde Grafana:

- Archivo sugerido: `auditx-overview.json`
- Se cargan automaticamente al iniciar el contenedor `grafana`.
- Folder en UI: `Audit-X` (definido en `grafana/provisioning/dashboards/dashboards.yml`).

Pasos recomendados:

1. En Grafana, abre un dashboard y exportalo como JSON.
2. Guardalo en esta carpeta.
3. Reinicia Grafana (`docker compose restart grafana`) o recrea stack.
