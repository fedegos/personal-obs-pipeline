# app/services/excel_uploader_service.rb
class ExcelUploaderService
  def self.call(file, bank_name, extra_params = {})
    # 1. Determinar el tipo de ingesta
    is_cloud_storage = NO_FILE_BANKS.include?(bank_name)

    # 2. Generar Key de trazabilidad
    file_key = if file
                 "raw/#{bank_name}/#{Time.now.to_i}_#{file.original_filename}"
    else
                 "api/#{bank_name}/#{Time.now.to_i}"
    end

    # 3. Registro en DB
    source_file = SourceFile.create!(
      bank: bank_name,
      file_key: file_key,
      status: "pending",
      extra_params: extra_params
    )

    # 4. Subida a MinIO (Solo si hay archivo físico)
    if file
      S3_CLIENT.put_object(
        bucket: S3_BUCKET_NAME,
        key: file_key,
        body: file.tempfile
      )
    end

    # 5. Notificar a Kafka con Payload Universal
    params = extra_params.to_h
    params[:filename] = file.original_filename if file

    Karafka.producer.produce_async(
      topic: "file_uploaded",
      payload: {
        metadata: {
          source_file_id: source_file.id,
          bank: bank_name,
          timestamp: Time.current
        },
        ingestion: {
          type: is_cloud_storage ? "external_api" : "s3_storage",
          location: file ? file_key : nil, # Path en S3 o null
          bucket: file ? S3_BUCKET_NAME : nil
        },
        params: params # spreadsheet_id, year, card_number, filename, etc.
      }.to_json
    )
  end
end
