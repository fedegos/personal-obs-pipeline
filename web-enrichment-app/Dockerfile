# Usa una versión estable de Ruby para 2026
FROM ruby:3.2.2

# Instalar dependencias necesarias para PostgreSQL y compilación de gemas
RUN apt-get update -qq && apt-get install -y \
    build-essential \
    libpq-dev \
    nodejs \
    curl

# Crear el directorio de trabajo (debe coincidir con el volumen del compose)
WORKDIR /app

# Instalar Bundler
RUN gem install bundler

# Copiar Gemfile para aprovechar el caché de Docker
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copiar el resto de la aplicación
COPY . .

# Exponer el puerto de Rails
EXPOSE 3000

# El comando final lo maneja el docker-compose
CMD ["rails", "server", "-b", "0.0.0.0"]
