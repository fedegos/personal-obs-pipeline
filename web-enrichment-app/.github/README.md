# CI para este repo

El CI **no** se ejecuta desde esta carpeta. GitHub Actions solo corre workflows que están en la **raíz** del repositorio, en `.github/workflows/`.

El pipeline unificado (Rails + Python) está en la raíz del monorepo:

- **Raíz:** [../../.github/workflows/ci.yml](../../.github/workflows/ci.yml)

Los jobs de Rails usan `working-directory: web-enrichment-app` para lint (Brakeman, bundler-audit, importmap, RuboCop) y tests (Minitest y system tests).
