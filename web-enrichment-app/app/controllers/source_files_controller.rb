# app/controllers/source_files_controller.rb
class SourceFilesController < ApplicationController
  def index
    @source_files = SourceFile.order(created_at: :desc).limit(15)
  end

  def create
    bank = params[:bank]

    required_keys = BANK_SCHEMAS.dig(bank, :required_keys) # Necesitaríamos adaptar el YAML para esto

    if params[:file].present? && bank.present? && required_keys_present?(bank, params[:extra_params])
      # 1. Extraemos los parámetros opcionales y los convertimos en un Hash
      # Usamos .to_h para que ExcelUploaderService reciba un objeto nativo de Ruby
      extra_params = params.fetch(:extra_params, {}).permit!.to_h
      
      # 2. Pasamos los parámetros al servicio
      ExcelUploaderService.call(params[:file], bank, extra_params)
      redirect_to upload_path, notice: "Archivo en cola de procesamiento."
    else
      redirect_to upload_path, alert: "Faltan datos obligatorios para el banco seleccionado."
    end
  end

  private

  def required_keys_present?(bank, submitted_params)
    schema = BANK_SCHEMAS[bank]
    return false unless schema
    
    schema.each do |field|
      if field[:required] && submitted_params[field[:key]].blank?
        return false # Falta un campo requerido para este banco específico
      end
    end
    true
  end
  
end
