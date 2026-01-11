# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  # Saltamos la verificación de autenticidad para facilitar pruebas locales con Turbo
  skip_before_action :verify_authenticity_token, only: [:approve]

 def index
    @pending = Transaction.where(aprobado: false).order(fecha: :desc)
    
    # Creamos un hash: { "Supermercado" => ["Coto", "Dia"], "Hogar" => ["Luz", "Agua"] }
    @categories_map = CategoryRule.roots.includes(:children).each_with_object({}) do |root, hash|
      hash[root.name] = root.children.pluck(:name)
    end
    
    @categories_list = @categories_map.keys
  end

  def approve
    @transaction = Transaction.find(params[:id])
    
    # Intentamos actualizar con los datos del formulario (categoría y sentimiento)
    if @transaction.update(transaction_params.merge(aprobado: true))
      
      # 1. Publicar el evento enriquecido en Kafka Clean (hacia Telegraf -> InfluxDB)
      publish_clean_event(@transaction)

      # 2. Responder al navegador
      respond_to do |format|
        format.turbo_stream # Busca approve.turbo_stream.erb
        format.html { redirect_to transactions_path, notice: "Aprobado." }
      end
    else
      # En caso de error de validación
      respond_to do |format|
        format.html { redirect_to transactions_path, alert: "No se pudo procesar la aprobación." }
      end
    end
  end

  private

  def transaction_params
    # Permitimos los campos de enriquecimiento manual
    params.require(:transaction).permit(:categoria, :sub_categoria,:sentimiento)
  end

  def publish_clean_event(transaction)
    # Construimos el esquema final que Telegraf espera para InfluxDB
    payload = {
      event_id:      transaction.event_id,
      fecha:         transaction.fecha.iso8601, # Formato estándar para InfluxDB
      monto:         transaction.monto.to_f,
      moneda:        transaction.moneda,
      detalles:      transaction.detalles,
      categoria:     transaction.categoria,
      sub_categoria: transaction.sub_categoria, # Incluido para InfluxDB
      sentimiento:   transaction.sentimiento,
      red:           transaction.red,
      processed_at:  Time.current.iso8601
    }

    # Publicación asíncrona para no bloquear la interfaz de usuario
    begin
      Karafka.producer.produce_async(
        topic: 'transacciones_clean',
        payload: payload.to_json,
        key: transaction.event_id
      )
    rescue => e
      # Logeamos el error pero permitimos que la app siga (el registro ya está en Postgres)
      Rails.logger.error "❌ Error publicando en Kafka Clean: #{e.message}"
    end
  end
end
