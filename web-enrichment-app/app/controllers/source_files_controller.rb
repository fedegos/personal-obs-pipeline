class SourceFilesController < ApplicationController
  def index
    @source_files = SourceFile.order(created_at: :desc).limit(15)
  end

  # app/controllers/source_files_controller.rb
  def create
    bank = params[:bank]
    schema = BANK_SCHEMAS[bank]
    
    # Nueva lógica: ¿Requiere archivo?
    needs_file = !NO_FILE_BANKS.include?(bank)
    file_present = params[:file].present?

    if (file_present || !needs_file) && schema.present? && required_keys_present?(schema, params[:extra_params])
      extra_params = params.fetch(:extra_params, {}).permit!.to_h
      
      # Pasamos nil en el archivo si no es necesario
      ExcelUploaderService.call(params[:file], bank, extra_params)
      
      redirect_to upload_path, notice: "Procesamiento de #{bank.upcase} iniciado correctamente."
    else
      msg = file_present ? "Faltan parámetros obligatorios." : "Debe adjuntar un archivo para este banco."
    redirect_to upload_path, alert: msg
  end
end
  private

  def required_keys_present?(schema, submitted_params)
    # Si el esquema está vacío (como en VISA), la validación pasa por defecto
    return true if schema.empty?
    
    # Verificamos cada campo definido en el inicializador
    schema.each do |field|
      if field[:required]
        # Si es requerido y el parámetro está en blanco, la validación falla
        # Usamos .dig en submitted_params porque es un Hash, aquí sí es correcto
        if submitted_params.blank? || submitted_params[field[:key]].blank?
          return false
        end
      end
    end
    true
  end
end
