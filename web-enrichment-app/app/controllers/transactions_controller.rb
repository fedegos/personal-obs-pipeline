class TransactionsController < ApplicationController
  # Evitamos errores de autenticidad para pruebas locales rápidas
  skip_before_action :verify_authenticity_token, only: [:approve]

  def index
    # Solo mostramos lo que NO está aprobado
    @pending = Transaction.where(aprobado: false).order(fecha: :desc)
  end

  def approve
    @transaction = Transaction.find(params[:id])
    
    if @transaction.update(transaction_params.merge(aprobado: true))
      # PUBLICACIÓN EN KAFKA: Aquí es donde enviamos el dato "limpio"
      # Este payload es el que leerá Telegraf para InfluxDB
      payload = {
        event_id: @transaction.event_id,
        fecha: @transaction.fecha.isoformat,
        monto: @transaction.monto.to_f,
        moneda: @transaction.moneda,
        detalles: @transaction.detalles,
        categoria: @transaction.categoria,
        sentimiento: @transaction.sentimiento,
        red: @transaction.red
      }

      Karafka.producer.produce_async(
        topic: 'transacciones_clean',
        payload: payload.to_json,
        key: @transaction.event_id
      )
      
      redirect_to transactions_path, notice: "Transacción enviada a InfluxDB correctamente."
    else
      redirect_to transactions_path, alert: "Error al aprobar la transacción."
    end
  end

  private

  def transaction_params
    params.require(:transaction).permit(:categoria, :sentimiento)
  end
end