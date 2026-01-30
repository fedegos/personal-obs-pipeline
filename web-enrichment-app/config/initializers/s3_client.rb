# config/initializers/s3_client.rb

# En 2026, durante 'assets:precompile', Rails no necesita un cliente S3 real.
# Usamos un bloque condicional para evitar el KeyError.

if ENV["SECRET_KEY_BASE_DUMMY"]
  # Durante el Build de Docker, definimos constantes vacías o dummy
  S3_CLIENT = nil
  S3_BUCKET_NAME = "bank-ingestion"
else
  # En ejecución real (Dev o Prod), usamos los valores del entorno
  S3_CLIENT = Aws::S3::Client.new(
    endpoint: ENV.fetch("AWS_ENDPOINT", "http://s3-server:9000"),
    force_path_style: true,
    region: ENV.fetch("AWS_REGION", "us-east-1"),
    access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
    s3_us_east_1_regional_endpoint: "regional"
  )

  S3_BUCKET_NAME = ENV.fetch("AWS_BUCKET_NAME", "bank-ingestion")
end
