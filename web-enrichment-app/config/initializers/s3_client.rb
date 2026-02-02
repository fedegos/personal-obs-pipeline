# config/initializers/s3_client.rb

# Build de Docker, test (CI) o sin credenciales: no crear cliente S3 real
if ENV["SECRET_KEY_BASE_DUMMY"] || Rails.env.test? || ENV["AWS_ACCESS_KEY_ID"].blank?
  S3_CLIENT = nil
  S3_BUCKET_NAME = ENV.fetch("AWS_BUCKET_NAME", "bank-ingestion")
else
  S3_CLIENT = Aws::S3::Client.new(
    endpoint: ENV.fetch("AWS_ENDPOINT", "http://s3-server:9000"),
    force_path_style: true,
    region: ENV.fetch("AWS_REGION", "us-east-1"),
    access_key_id: ENV.fetch("AWS_ACCESS_KEY_ID"),
    secret_access_key: ENV.fetch("AWS_SECRET_ACCESS_KEY"),
    s3_us_east_1_regional_endpoint: "regional"
  )
  S3_BUCKET_NAME = ENV.fetch("AWS_BUCKET_NAME", "bank-ingestion")

  # Crear el bucket si no existe (MinIO no lo crea automáticamente)
  begin
    S3_CLIENT.head_bucket(bucket: S3_BUCKET_NAME)
  rescue Aws::S3::Errors::NotFound, Aws::S3::Errors::NoSuchBucket
    S3_CLIENT.create_bucket(bucket: S3_BUCKET_NAME)
    Rails.logger.info "Bucket '#{S3_BUCKET_NAME}' creado en MinIO."
  end
end
