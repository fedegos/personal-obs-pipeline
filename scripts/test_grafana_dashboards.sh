#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -f ".env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

: "${INFLUX_ORG:?INFLUX_ORG no definido en .env}"
: "${INFLUX_TOKEN:?INFLUX_TOKEN no definido en .env}"

if ! docker compose ps --status running --services | awk '$0=="influxdb"{found=1} END{exit(found?0:1)}'; then
  echo "ERROR: el servicio influxdb no esta corriendo. Ejecuta: make up"
  exit 1
fi

python3 - <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()
DASHBOARDS_DIR = ROOT / "grafana" / "dashboards"

VAR_DEFAULTS = {
    "origen": "definitivo",
    "fecha_vencimiento": "__all",
    "red": "__all",
    "numero_tarjeta": "__all",
}
VAR_RE = re.compile(r"\$\{([^}]+)\}")


def iter_panels(panels):
    for panel in panels or []:
        yield panel
        if panel.get("panels"):
            yield from iter_panels(panel.get("panels"))


def normalize_query(query: str) -> str:
    query = VAR_RE.sub(lambda m: VAR_DEFAULTS.get(m.group(1), "__all"), query)
    query = query.replace("v.timeRangeStart", "-180d")
    query = query.replace("v.timeRangeStop", "now()")
    return query


def run_query(query: str) -> tuple[int, str]:
    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "influxdb",
        "influx",
        "query",
        query,
        "--org",
        os.environ["INFLUX_ORG"],
        "--token",
        os.environ["INFLUX_TOKEN"],
    ]
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=ROOT)
    output = (result.stderr.strip() or result.stdout.strip()).splitlines()
    message = output[-1] if output else "unknown error"
    return result.returncode, message


errors = []
checked = 0

for dashboard_path in sorted(DASHBOARDS_DIR.glob("*.json")):
    with dashboard_path.open(encoding="utf-8") as fh:
        dashboard = json.load(fh)

    for panel in iter_panels(dashboard.get("panels", [])):
        for target in panel.get("targets", []):
            query = target.get("query")
            if not query:
                continue

            checked += 1
            code, message = run_query(normalize_query(query))
            if code != 0:
                errors.append(
                    (
                        dashboard_path.name,
                        panel.get("id"),
                        panel.get("title", "Sin titulo"),
                        target.get("refId", "?"),
                        message,
                    )
                )

print(f"Queries validadas: {checked}")
if errors:
    print(f"FALLAS: {len(errors)}")
    for dashboard, panel_id, title, ref_id, message in errors:
        print(f"- {dashboard} | panel {panel_id} | {title} | {ref_id} | {message}")
    sys.exit(1)

print("OK: todas las queries Flux de dashboards son validas")
PY
