# Despliegue en Coolify (Hetzner)

*Guía para evitar fallos de build y timeouts.*

## Resumen

El proyecto se despliega con `docker compose build` desde Coolify. El servicio **web** (Rails) es el más costoso de construir por las gemas con extensiones nativas (nokogiri, pg, bcrypt, thruster) y la precompilación de assets. En VPS con recursos limitados puede fallar por **OOM** o **timeout**.

## Optimizaciones ya aplicadas en el Dockerfile

- **Eliminación de nodejs/npm**: `tailwindcss-ruby` incluye el CLI embebido; no hace falta Node.
- **Eliminación de git**: no se usa para `bundle install` en producción.
- **`BUNDLE_JOBS=2`** y **`MAKEFLAGS=-j2`**: reducen el paralelismo para bajar uso de RAM durante la compilación de extensiones nativas.

## Configuración recomendada en Coolify

### 1. Memoria del build

- **Mínimo recomendado**: 2 GB RAM para el contenedor de build.
- Si el build falla con "killed" o exit 255 sin mensaje claro, suele ser OOM.
- En Coolify: **Server → Build** o **Application → Build** → revisar límites de memoria del runner.

### 2. Timeout de build

- El build completo (web + karafka + ingestion_worker) puede tardar **5–10 minutos** en la primera vez.
- Aumentar el timeout de build si Coolify tiene uno configurado (p. ej. 15–20 min para la primera build).
- En builds subsiguientes, el cache de capas acelera bastante.

### 3. Build en paralelo

- Coolify puede construir los servicios en paralelo. Si hay límites de RAM, construir en serie puede ayudar.
- El orden natural es: ingestion_worker (más rápido), luego web y karafka (comparten la misma imagen base).

## Problemas conocidos y soluciones

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `exit code 255` durante bundle install | OOM (memoria insuficiente) | Aumentar RAM del build; ya aplicado `BUNDLE_JOBS=2` |
| "Gracefully shutting down build container" | Timeout de Coolify | Aumentar timeout de build |
| `numpy` yanked en pip | numpy 2.4.0 retirado en PyPI | Ya corregido a `numpy>=2.2.0,<2.4.0` en requirements.txt |
| Build muy lento | Falta de cache de capas | Verificar que Coolify use cache de Docker; no limpiar cache entre deploys |

## Verificación local

Para reproducir el build en local y estimar recursos:

```bash
# Desde la raíz del proyecto
docker compose -f docker-compose.prod.yml build web
```

Si falla en local con poca RAM, aumentarla o ajustar `BUNDLE_JOBS` en el Dockerfile.

## Documentación relacionada

- [OPERATIONS.md](OPERATIONS.md) — Runbook general
- [ARCHITECTURE.md](ARCHITECTURE.md) — Flujo de datos
