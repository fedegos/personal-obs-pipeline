# app/controllers/source_files_controller.rb
class SourceFilesController < ApplicationController
  ITEMS_PER_PAGE = 20

  def index
    base = SourceFile.order(created_at: :desc)
    @page = [ params[ :page ].to_i, 1 ].max
    offset = (@page - 1) * ITEMS_PER_PAGE
    @source_files = base.offset(offset).limit(ITEMS_PER_PAGE)
    has_more = base.offset(offset + ITEMS_PER_PAGE).limit(1).exists?
    @next_page = has_more ? @page + 1 : nil

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    bank = params[:bank]
    schema = BANK_SCHEMAS[bank]

    # 1. Validaciones de estado
    # Usamos .any? o chequeamos nil para permitir arrays vacíos []
    bank_exists = BANK_SCHEMAS.key?(bank)
    needs_file = !NO_FILE_BANKS.include?(bank)
    file_present = params[:file].present?

    # 2. Lógica de validación unificada
    # Quitamos schema.present? porque [] es falsey en .present?
    if bank_exists && (file_present || !needs_file) && required_keys_present?(schema, params[:extra_params])
      extra_params = params.fetch(:extra_params, {}).permit(
        :credit_card, :spreadsheet_id, :sheet, :card_number, :card_network, :year, :fecha_vencimiento, :fecha_vencimiento
      ).to_h

      ExcelUploaderService.call(params[:file], bank, extra_params)

      redirect_to upload_path, notice: "Procesamiento de #{bank.upcase} iniciado correctamente."
    else
      # 3. Construcción del mensaje de error dinámico
      if !bank_exists
        msg = "El banco seleccionado no es válido."
      elsif needs_file && !file_present
        msg = "Debe adjuntar un archivo para el banco #{bank.upcase}."
      else
        msg = "Faltan parámetros obligatorios para el extractor de #{bank.upcase}."
      end

      redirect_to upload_path, alert: msg
    end
  end

  private

  def required_keys_present?(schema, submitted_params)
    # Si el esquema es nil o vacío (VISA), no hay requisitos
    return true if schema.blank?

    schema.each do |field|
      if field[:required]
        # Si es requerido, validamos presencia en el hash de parámetros
        if submitted_params.blank? || submitted_params[field[:key]].blank?
          return false
        end
      end
    end
    true
  end
end
