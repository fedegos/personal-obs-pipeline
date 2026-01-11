# Guía: Sincronización de Gemas en Rails + Docker (2026)

## 1. El Problema
Al intentar ejecutar comandos como `bundle exec karafka server` o iniciar el servidor Rails, aparece el error:
`bundler: command not found: karafka` o `Install missing gem executables`.

Esto ocurre incluso después de haber ejecutado `docker compose build`.

## 2. La Causa Técnica
El problema reside en el conflicto entre la **Imagen de Docker** y el **Volumen de Desarrollo**:

1.  **Build Estático:** Durante el `docker compose build`, las gemas se instalan dentro de la imagen de Docker (en una capa interna).
2.  **Volumen Dominante:** En el archivo `docker-compose.yml`, tienes configurado un volumen: `- ./web-enrichment-app:/app`.
3.  **El "Solapamiento":** Al iniciar el contenedor, Docker **monta tu carpeta local encima** de la carpeta `/app` de la imagen. 
4.  **Resultado:** Si en tu carpeta local (Windows/WSL/Linux) no existe el archivo `Gemfile.lock` actualizado con la nueva gema, el contenedor "ignora" lo que instaló en el build y asume que la gema no existe, porque lee la configuración de tu carpeta local.

---

## 3. La Solución Definitiva

Para solucionar esto, debemos sincronizar el estado de las gemas del contenedor con tu carpeta local.

### Paso 1: Actualizar el Dockerfile
Asegúrate de que tu `./web-enrichment-app/Dockerfile` instale las gemas correctamente:

```dockerfile
FROM ruby:3.2.2

RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs

WORKDIR /app

# Primero copiamos gemas para cachear la instalación
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Luego el resto del código
COPY . .
```

### Paso 2: Sincronizar el Gemfile.lock con el Host
Ejecuta este comando para forzar la instalación y que el archivo `.lock` se escriba en tu carpeta local gracias al volumen:

```bash
docker compose run --rm web bundle install
```
*   **`run --rm`**: Crea un contenedor temporal y lo borra al terminar.
*   **`bundle install`**: Actualiza el `Gemfile.lock` en tu computadora.

### Paso 3: Reiniciar el Entorno
Una vez sincronizado el archivo de bloqueo, levanta los servicios:

```bash
# Limpiar procesos viejos y PID fantasmas
docker compose down
rm -f web-enrichment-app/tmp/pids/server.pid

# Iniciar todo
docker compose up -d
```

---

## 4. Resumen de Flujo de Trabajo (Best Practices 2026)

¿Cuándo usar cada comando?

*   **¿Agregaste una gema nueva al Gemfile?**
    Ejecuta: `docker compose run --rm web bundle install`
*   **¿La app falla con "Command not found"?**
    Ejecuta: `docker compose run --rm web bundle install`
*   **¿Cambiaste algo en el Dockerfile o dependencias de sistema?**
    Ejecuta: `docker compose build`
*   **¿Vas a desplegar en AWS EC2 (Producción)?**
    Allí solo usarás `docker build`, ya que en producción **no se usan volúmenes** que pisen el código, y la imagen debe ser autónoma.
