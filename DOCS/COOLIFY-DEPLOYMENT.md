# Despliegue en Coolify (Hetzner)

*Guía para evitar fallos de build y timeouts.*

## Resumen

El proyecto puede desplegarse de dos formas en Coolify:

1. **Con imágenes preconstruidas (GHCR)** — recomendado. Las imágenes se construyen en GitHub Actions y se publican en GitHub Container Registry. Coolify solo hace `docker pull`. Evita OOM y timeouts.
2. **Con build local** — Coolify ejecuta `docker compose build`. El servicio **web** (Rails) es el más costoso por las gemas con extensiones nativas y la precompilación de assets. En VPS con recursos limitados puede fallar por **OOM** o **timeout**.

---

## Despliegue con imágenes preconstruidas (GHCR)

### Flujo recomendado (deploy solo tras el build)

1. Push/merge a `main` → GitHub Actions construye web e ingestion-engine.
2. Las imágenes se publican en `ghcr.io/OWNER/personal-obs-pipeline-web` y `personal-obs-pipeline-ingestion`.
3. **Al terminar el build**, el workflow llama al webhook de Coolify → Coolify hace pull y despliega.

**Importante:** Coolify no debe desplegar al recibir el webhook de Git (push). Eso ocurriría antes de que las imágenes existan. Debe desplegar solo cuando GitHub Actions llame al webhook tras el build.

### Configuración en Coolify

1. **Desactivar Auto Deploy en push:**
   - Ir a la aplicación → **Advanced**
   - **Desactivar** "Auto Deploy" (para que Coolify no despliegue al recibir el webhook de push de GitHub).

2. **Configurar el webhook para deploy post-build:**
   - En la misma sección Advanced, copiar la **Webhook URL** de deploy.
   - Crear un **API Token** en Coolify: **Settings → Keys & Tokens → API tokens** → Create New Token (con permisos para deploy).
   - En GitHub: **Settings → Secrets and variables → Actions** → Añadir estos secrets:
     - `COOLIFY_WEBHOOK_URL`: la URL del webhook.
     - `COOLIFY_DEPLOY_TOKEN`: el API token de Coolify (Bearer auth).
   - El workflow llama al webhook solo cuando ambos builds (web e ingestion) terminan con éxito.

3. **Variables de entorno** en la aplicación:

   - `GHCR_WEB_IMAGE=ghcr.io/USUARIO/personal-obs-pipeline-web:latest`
   - `GHCR_INGESTION_IMAGE=ghcr.io/USUARIO/personal-obs-pipeline-ingestion:latest`
   - Sustituye `USUARIO` por tu usuario u organización de GitHub (ej. `fedegos`). **Verifica que no haya typos** (p. ej. `fedgos` en lugar de `fedegos` da error "denied").

4. **Imágenes públicas:** Si el repo es público y las imágenes de GHCR son públicas, no hace falta login.
5. **Imágenes privadas:** Crear un [PAT](https://github.com/settings/tokens) con `read:packages`. En Coolify: **Settings → Docker Registry** (o equivalente) y añadir credenciales para `ghcr.io` (usuario = GitHub user, contraseña = PAT).

### Primera ejecución

Tras el primer merge a `main`, espera a que termine el workflow "Build and Push to GHCR" en GitHub Actions. Si Auto Deploy está desactivado, el primer deploy se hará cuando el workflow llame al webhook (o manualmente desde Coolify).

### ¿Se puede hacer el build en el branch antes del merge?

Sí, pero no soluciona el desfase. Si el workflow corriera en PRs o branches:
- Las imágenes se etiquetarían con `pr-123` o `branch-name`, no `latest`.
- Coolify usa `latest` por defecto.
- Tras el merge a `main`, habría que volver a construir y pushear `latest` de todos modos.

La opción recomendada es mantener el build solo en `main` y usar el webhook post-build para disparar Coolify.

---

## Despliegue con build local (alternativa)

El `docker-compose.prod.yml` está pensado para usar imágenes de GHCR. Si quieres que Coolify construya las imágenes localmente (ej. sin tener configurado GHCR), crea un override o un compose alternativo que redefina `web`, `karafka_server` e `ingestion_worker` con `build` en lugar de `image`.

## Optimizaciones ya aplicadas en el Dockerfile

- **Eliminación de nodejs/npm**: `tailwindcss-ruby` incluye el CLI embebido; no hace falta Node.
- **Eliminación de git**: no se usa para `bundle install` en producción.
- __`BUNDLE_JOBS=2`__ y __`MAKEFLAGS=-j2`__: reducen el paralelismo para bajar uso de RAM durante la compilación de extensiones nativas.

## Configuración recomendada en Coolify

### 1. Memoria del build

- **Mínimo recomendado**: 2 GB RAM para el contenedor de build.
- Si el build falla con "killed" o exit 255 sin mensaje claro, suele ser OOM.
- En Coolify: **Server → Build** o **Application → Build** → revisar límites de memoria del runner.

### 2. Timeout de build

- El build completo (web + karafka + ingestion_worker) puede tardar __5–10 minutos__ en la primera vez.
- Aumentar el timeout de build si Coolify tiene uno configurado (p. ej. 15–20 min para la primera build).
- En builds subsiguientes, el cache de capas acelera bastante.

### 3. Build en paralelo

- Coolify puede construir los servicios en paralelo. Si hay límites de RAM, construir en serie puede ayudar.
- El orden natural es: ingestion_worker (más rápido), luego web y karafka (comparten la misma imagen base).

## Problemas conocidos y soluciones

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `Head "https://ghcr.io/v2/.../manifests/latest": denied` | Typo en usuario (ej. `fedgos` en vez de `fedegos`) | Revisar `GHCR_WEB_IMAGE` y `GHCR_INGESTION_IMAGE` en Coolify |
| Deploy falla justo tras el merge; imágenes no existen | Coolify despliega en push antes de que termine el build | Desactivar Auto Deploy; usar solo webhook tras build |
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
