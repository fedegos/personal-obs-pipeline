# app/services/excel_uploader_service.rb
class ExcelUploaderService
  def self.call(file, bank_name, extra_params = {})
    # 1. Registro en DB con los extra_params
    source_file = SourceFile.create!(
      bank: bank_name,
      file_key: "raw/#{bank_name}/#{Time.now.to_i}_#{file.original_filename}",
      status: 'pending',
      extra_params: extra_params
    )

    # 2. Subida usando el cliente configurado con tu .env
    S3_CLIENT.put_object(
      bucket: S3_BUCKET_NAME,
      key: source_file.file_key,
      body: file.tempfile
    )

    # 3. Kafka con el payload enriquecido para los **kwargs de Python
    Karafka.producer.produce_async(
      topic: 'file_uploaded',
      payload: { 
        source_file_id: source_file.id, 
        bank: bank_name, 
        s3_key: source_file.file_key,
        params: extra_params 
      }.to_json
    )
  end
end
