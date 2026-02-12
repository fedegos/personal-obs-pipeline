# Referencia: circuito de integración (CI)

Este documento resume el flujo Git/CI y los comandos que debes usar para que tus cambios respeten el circuito de integración antes de abrir o mergear un PR.

---

## 1. Flujo Git

```
rama (feature/xxx o develop)
  → commit + push
  → Pull Request a main
  → CI en verde (lint + tests Rails + lint + tests Python)
  → merge a main
  → Coolify despliega desde main
```

- **No** commitear directo a `main`. Trabajar siempre en una rama.
- Merge a `main` **solo** vía Pull Request y con **CI en verde**.
- El workflow está en la raíz: [../.github/workflows/ci.yml](../.github/workflows/ci.yml).

---

## 2. Trabajo con Git: desde el branch hasta el Pull Request

Pasos concretos para trabajar en una rama y llevar los cambios a `main` vía PR.

### 2.1 Partir de main actualizado

```bash
git checkout main
git pull origin main
```

### 2.2 Crear y usar una rama

```bash
# Crear rama (ej. feature/nombre o fix/descripcion)
git checkout -b feature/mi-cambio

# Trabajar, editar archivos...
# Luego añadir y commitear
git add .
git status   # revisar qué va en el commit
git commit -m "Descripción clara del cambio"
```

### 2.3 Correr lint y tests antes de push

Corre los comandos de la [sección 3](#3-comandos-locales-para-reproducir-el-ci) (Rails y/o Python según lo que tocaste). Si algo falla, corrige y vuelve a commitear.

### 2.4 Subir la rama y abrir el Pull Request

```bash
# Primera vez que subes esta rama
git push -u origin feature/mi-cambio

# Siguientes pushes (después de más commits)
git push
```

Luego en GitHub:

1. Entra al repo y acepta el aviso **“Compare & pull request”** (o ve a **Pull requests → New pull request**).
2. Base: `main`, compare: tu rama (ej. `feature/mi-cambio`).
3. Título y descripción del PR.
4. **Create pull request**.

### 2.5 Esperar al CI

- En la página del PR verás los checks del workflow (rails-lint, rails-rubocop, rails-test, python-lint, python-test, etc.).
- Si algo falla, corrige en la misma rama, haz commit y push; el CI se vuelve a ejecutar.
- No hagas merge hasta que todos los checks estén en verde.

### 2.6 Merge a main

- En el PR: **Merge pull request** (merge o squash, según la política del repo).
- Borrar la rama en GitHub después del merge (opcional).
- Localmente, volver a main y actualizar:

```bash
git checkout main
git pull origin main
```

A partir de ahí Coolify despliega desde `main` (si está configurado el deploy en push a main).

---

## 3. Qué ejecuta el CI

| Job | Qué hace |
|-----|----------|
| **rails-lint** | Brakeman, bundler-audit, importmap audit |
| **rails-rubocop** | RuboCop (solo si cambian archivos en `web-enrichment-app/`) |
| **rails-test** | Postgres + `bin/rails db:test:prepare test` + reporte SimpleCov |
| **rails-system-test** | `bin/rails db:test:prepare test:system` |
| **python-lint** | Ruff check (solo si cambian archivos en `ingestion-engine/`) |
| **python-test** | `pytest --cov` + reporte pytest-cov |

Los jobs de Rails solo corren si tocaste `web-enrichment-app/` o `.github/workflows/ci.yml`; los de Python, si tocaste `ingestion-engine/` o el workflow. Si tocaste ambos, se ejecutan todos.

---

## 4. Comandos locales para reproducir el CI

Ejecuta estos comandos **antes de hacer push** (o antes de abrir el PR) para evitar fallos en el CI. Son los mismos que usa el CI (ver [sección 3](#3-qué-ejecuta-el-ci)).

### Rails (web-enrichment-app)

**Con Docker (stack levantado):**

```bash
# Lint (mismo que CI: solo verificación, sin -A)
docker compose exec web bin/rubocop -f github

# Seguridad (Brakeman + bundler-audit + importmap)
docker compose exec web bin/brakeman --no-pager
docker compose exec web bin/bundler-audit
docker compose exec web bin/importmap audit

# Tests
make test              # todo (Rails + Python, unit/controller)
make test-rails        # solo Rails (Minitest, unit/controller)
make test-rails-system # solo Rails system tests (Capybara/Selenium)
make test-python       # solo Python (pytest)

# Profiling de tests Rails lentos (muestra los 25 más lentos)
make test-rails-profile   # o make test-profile; ver DOCS/TEST-PROFILING.md
```

**Sin Docker (desde `web-enrichment-app/`):**

```bash
cd web-enrichment-app
bin/rubocop -f github
bin/brakeman --no-pager
bin/bundler-audit
bin/importmap audit
RAILS_ENV=test bin/rails db:test:prepare test
```

**Make (solo lint con auto-fix):** `make lint` usa `rubocop -A`; el CI usa `rubocop -f github` sin `-A`. Para alinearte al CI, corre `bin/rubocop -f github` como arriba.

---

### Python (ingestion-engine)

**Desde `ingestion-engine/`:**

```bash
cd ingestion-engine
pip install -r requirements.txt   # o: .venv/bin/pip install -r requirements.txt
ruff check .
python -m pytest tests/ -v --tb=short
```

**Con venv:**

```bash
cd ingestion-engine
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/ruff check .
.venv/bin/python -m pytest tests/ -v --tb=short
```

---

## 5. Resumen de targets de tests

| Comando | Alcance |
|---------|---------|
| `make test` | Todo (Rails unit/controller + Python) |
| `make test-rails` | Solo Rails (Minitest, unit/controller) |
| `make test-rails-system` | Solo Rails system tests (Capybara/Selenium) |
| `make test-python` | Solo Python (pytest) |

Los targets `ci-rails-test`, `ci-rails-system-test` y `ci-python-test` delegan en los anteriores.

---

## 6. Cobertura de código

El proyecto incluye herramientas de cobertura para Rails (SimpleCov) y Python (pytest-cov).

### Comandos de cobertura

| Comando | Alcance |
|---------|---------|
| `make test-coverage` | Todo (Rails + Python) |
| `make test-rails-coverage` | Solo Rails |
| `make test-python-coverage` | Solo Python |

### Rails (SimpleCov)

SimpleCov se ejecuta automaticamente al correr los tests de Rails. El reporte se genera en `web-enrichment-app/coverage/index.html`.

```bash
# Con Docker
make test-rails-coverage   # o make test-coverage para todo

# Sin Docker
cd web-enrichment-app && RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test
# Abrir coverage/index.html en el navegador
```

### Python (pytest-cov)

```bash
# Con Docker
make test-python-coverage   # o make test-coverage para todo

# Sin Docker
cd ingestion-engine
python -m pytest --cov=. --cov-report=term-missing --cov-report=html tests/
# Abrir htmlcov/index.html en el navegador
```

### Umbrales

- **Objetivo inicial:** 90% de cobertura minima
- **Objetivo final:** 100% de codigo propio

Los reportes de cobertura se suben como artefactos en el CI de GitHub Actions.

---

## 7. Resumen rápido

**Todos los controles del CI de una vez (desde la raíz del repo, con Docker levantado):**

```bash
make ci
```

Eso ejecuta en orden: Brakeman, bundler-audit, importmap audit, RuboCop, tests Rails (Minitest), system tests Rails, Ruff check, pytest. Si alguno falla, se detiene.

**Controles sueltos (Make):**

| Objetivo | Comando |
|----------|--------|
| Todo el CI | `make ci` |
| Solo Rails (lint + tests) | `make ci-rails-lint ci-rails-rubocop ci-rails-test ci-rails-system-test` |
| Solo Python (lint + tests) | `make ci-python-lint ci-python-test` |
| Lint Rails | `make ci-rails-rubocop` (o `docker compose exec web bin/rubocop -f github`) |
| Seguridad Rails | `make ci-rails-lint` (Brakeman + bundler-audit + importmap) |
| Tests Rails (unit/controller) | `make test-rails` o `make ci-rails-test` |
| System tests Rails | `make test-rails-system` o `make ci-rails-system-test` |
| Lint Python | `make ci-python-lint` |
| Tests Python | `make test-python` o `make ci-python-test` |

**Comandos directos (sin Make):** los mismos que en la [sección 4](#4-comandos-locales-para-reproducir-el-ci).

Si todos pasan en tu máquina, el CI debería pasar al hacer push (salvo diferencias de entorno).

---

## 8. Si el CI falla

- Revisa la pestaña **Actions** del repo en GitHub y el job que falló.
- Corrige en tu rama (lint o tests) y vuelve a hacer push al mismo PR; el CI se vuelve a ejecutar.
- No hagas merge a `main` hasta que el CI esté en verde (y, si está configurado, hasta que se cumplan las reglas de branch protection).

---

## 9. Opcional: branch protection

En GitHub: **Settings → Branches → Add rule** para `main` → marcar **Require status checks to pass before merging** y elegir los jobs del CI (rails-lint, rails-rubocop, rails-test, python-lint, python-test, etc.). Así no se puede mergear si el CI falla.
