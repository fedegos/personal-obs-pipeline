# app/consumers/transactions_consumer_backfill.rb
# VERSIÓN TEMPORAL PARA BACKFILL DE numero_tarjeta
# 
# INSTRUCCIONES:
# 1. Renombra este archivo a transactions_consumer.rb (haz backup del original)
# 2. Ejecuta: make rebind-karafka-consumer
# 3. Reinicia: make restart-karafka-worker
# 4. Espera a que procese los mensajes
# 5. Restaura el consumer original
#
# Esta versión actualiza SOLO numero_tarjeta en transacciones existentes (incluso aprobadas)
# sin modificar otros campos.

class TransactionsConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      data = message.payload
      
      transaction = Transaction.find_by(event_id: data['event_id'])
      
      # Si la transacción existe y tiene numero_tarjeta en el mensaje pero no en la DB
      if transaction && data['numero_tarjeta'].present? && transaction.numero_tarjeta.blank?
        transaction.update_column(:numero_tarjeta, data['numero_tarjeta'])
        Karafka.logger.info "✅ Backfill: numero_tarjeta actualizado para #{transaction.event_id}"
        next
      end
      
      # Si no existe, crear normalmente (solo si no está aprobada)
      next if transaction&.aprobado?
      
      transaction ||= Transaction.new(event_id: data['event_id'])
      
      results = CategorizerService.guess(data['detalles'])

      transaction.assign_attributes(
        fecha:        data['fecha_transaccion'],
        monto:        data['monto'],
        moneda:       data['moneda'],
        detalles:     data['detalles'],
        red:          data['red'],
        numero_tarjeta: data['numero_tarjeta'],
        categoria:    results[:category],
        sub_categoria:  results[:sub_category],
        sentimiento:  SentimentService.analyze(data["detalles"])
      )

      if transaction.save
        Karafka.logger.info "Transacción procesada (ID: #{transaction.event_id}) - Pendiente de aprobación"
      else
        Karafka.logger.error "Fallo al guardar transacción: #{transaction.errors.full_messages}"
      end
    end
  end
end
