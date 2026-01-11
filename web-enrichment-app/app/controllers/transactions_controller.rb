# app/controllers/transactions_controller.rb
class TransactionsController < ApplicationController
  # Saltamos la verificación de autenticidad para facilitar pruebas locales con Turbo
  skip_before_action :verify_authenticity_token, only: [:approve]

  def index
    # Cargamos solo las transacciones que esperan curaduría manual
    @pending = Transaction.where(aprobado: false).order(fecha: :desc)
  end

  def approve
    @transaction = Transaction.find(params[:id])
    
    # Intentamos actualizar con los datos del formulario (categoría y sentimiento)
    if @transaction.update(transaction_params.merge(aprobado: true))
      
      # 1. Publicar el evento enriquecido en Kafka Clean (hacia Telegraf -> InfluxDB)
      publish_clean_event(@transaction)

      # 2. Responder al navegador
      respond_to do |format|
        # Instrucción para que Turbo elimine la fila con el ID correspondiente (ej: transaction_42)
        format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(@transaction)) }
        # Respaldo para navegadores sin JS o recargas manuales
        format.html { redirect_to transactions_path, notice: "Transacción aprobada y enviada a InfluxDB." }
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
    params.require(:transaction).permit(:categoria, :sentimiento)
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
