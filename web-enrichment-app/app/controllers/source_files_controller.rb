class SourceFilesController < ApplicationController
  def index
    @source_files = SourceFile.order(created_at: :desc).limit(15)
  end

  def create
    bank = params[:bank]
    
    # Obtenemos el esquema directamente (es un Array de Hashes)
    # Gracias a .with_indifferent_access, no importa si bank es "amex" o :amex
    schema = BANK_SCHEMAS[bank]

    # Validamos: archivo presente, banco registrado y campos obligatorios llenos
    if params[:file].present? && schema.present? && required_keys_present?(schema, params[:extra_params])
      
      # Extraemos parámetros opcionales
      extra_params = params.fetch(:extra_params, {}).permit!.to_h
      
      # Llamada al servicio
      ExcelUploaderService.call(params[:file], bank, extra_params)
      
      redirect_to upload_path, notice: "Archivo para #{bank.upcase} en cola de procesamiento."
    else
      redirect_to upload_path, alert: "Error: Verifique que el archivo esté adjunto y todos los campos obligatorios del banco estén completos."
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
