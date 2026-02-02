# Profiling y mejoras: tests de Rails (Minitest)

Este documento explica por qué los tests de Rails pueden ser lentos y cómo identificar y mejorar los cuellos de botella.

---

## 1. Cómo hacer profiling

### Comando local (Docker)

```bash
make test-profile
```

Ejecuta los tests con la opción de Minitest `--profile 25`: al final muestra los **25 tests más lentos** ordenados por tiempo. Así ves qué archivos/casos de test consumen más tiempo.

### Sin Docker (desde web-enrichment-app)

```bash
cd web-enrichment-app
TESTOPTS="--profile 25" RAILS_ENV=test bin/rails db:test:prepare test
```

### Solo un directorio o archivo

```bash
docker compose exec -e RAILS_ENV=test -e TESTOPTS="--profile 10" web bin/rails test test/models
docker compose exec -e RAILS_ENV=test -e TESTOPTS="--profile 5" web bin/rails test test/services/recovery_from_clean_service_test.rb
```

Rails pasa las opciones de Minitest mediante la variable de entorno **`TESTOPTS`** (no usar `-- --profile 25` porque Rails puede interpretar el número como comando).

---

## 2. Causas habituales de lentitud

| Causa | Qué hace | Cómo mitigar |
|-------|----------|--------------|
| **`db:test:prepare`** | Carga esquema o migraciones antes de cada run. | En CI es necesario; en local puedes correr solo `test` si la DB de test ya está preparada (ej. tras un `test` previo). |
| **`fixtures :all`** | Carga todos los fixtures (YAML) para cada test. | **Aplicado:** cada archivo declara solo lo que usa (`fixtures :users, :category_rules`, etc.). Ver `test_helper.rb` y cada `*_test.rb`. |
| **`parallelize(workers: :number_of_processors)`** | N procesos en paralelo. En Docker, puede ser muchos → contención en PostgreSQL. | En `test_helper` se usa `PARALLEL_WORKERS` si está definido; si no, `:number_of_processors`. Para bajar carga: `PARALLEL_WORKERS=2 make test`. |
| **System tests** | Capybara + Selenium, arranque de navegador, esperas. | Ejecutar system tests aparte (`test:system`); no mezclarlos con unit/controller en el mismo run si quieres tiempos “limpios”. |
| **Conexiones pesadas** | Boot de Rails, Karafka, S3, Redis, etc. | En test, stubs/mocks para servicios externos; no conectar a Kafka/S3 real en unit tests. |
| **Tests que tocan DB de más** | Crear muchos registros, queries N+1 en tests. | Usar transacciones (por defecto); crear solo los datos necesarios; revisar tests que hacen muchos `create`. |
| **Docker `exec`** | Overhead de entrar al contenedor. | En local, correr tests fuera del contenedor si tienes Ruby y Postgres (más rápido para iterar). |

---

## 3. Mejoras aplicadas y recomendadas

### Aplicadas en este proyecto

1. **Fixtures por archivo**  
   Se quitó `fixtures :all` del `test_helper`. Cada archivo de test declara solo los fixtures que usa (ej. `fixtures :users, :category_rules`). Reduce carga por proceso y mejora tiempos (p. ej. CategoryRulesControllerTest pasó de ~5–7 s a ~0,6–2,7 s por test).

2. **Lógica de `parallelize`**  
   En `test_helper.rb`, si `PARALLEL_WORKERS` está definido y no vacío se usa ese número; si no, se usa `:number_of_processors`. Para reducir contención en Docker: `PARALLEL_WORKERS=2 make test`.

3. **Stub global de Karafka en test**  
   En `test_helper.rb`, `Karafka.producer` se reemplaza por un producer no-op que descarta todos los mensajes. Evita que los tests (DomainEventPublishable, Publishable, ExcelUploaderService) escriban a los tópicos de Kafka de desarrollo. Los tests que necesitan capturar payloads (PublishableTest, ExcelUploaderServiceTest) sobrescriben temporalmente el producer.

### Otras recomendadas

3. **Revisar el output de `make test-profile`**  
   Prioriza los tests que aparecen arriba en la lista (más lentos) y reduce creación de datos, llamadas externas o lógica pesada en setup.

4. **Separar system tests**  
   El CI ya corre `rails test` y `rails test:system` por separado. En local, usar `make test` para unit/controller y `make ci-rails-system-test` solo cuando toques system tests.

5. **No ejecutar `db:test:prepare` en cada iteración**  
   Si la DB de test ya está al día, puedes correr solo `bin/rails test` (sin `db:test:prepare`) para ahorrar unos segundos en cada run.

---

## 4. Referencias

- [Minitest options](https://minitest.rubystyle.guide/#running-tests) (`--profile`, `-v`, etc.)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- Comandos locales del CI: [CI-REFERENCIA.md](CI-REFERENCIA.md)
