# config/initializers/s3_client.rb
S3_CLIENT = Aws::S3::Client.new(
  endpoint: ENV.fetch('AWS_ENDPOINT', 'http://s3-server:9000'), # Agregaremos esto al .env o usamos default
  force_path_style: true,
  region: ENV.fetch('AWS_REGION', 'us-east-1'),
  access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'),
  secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
  s3_us_east_1_regional_endpoint: "regional"
)

S3_BUCKET_NAME = 'bank-ingestion' # Reutilizamos o definimos uno específico 