# app/consumers/transactions_consumer.rb
class TransactionsConsumer < ApplicationConsumer
  def consume
    # Procesamos en bloque para mayor eficiencia en Kafka
    messages.each do |message|
      data = message.payload

      # Buscamos por event_id (el hash generado en Python)
      transaction = Transaction.find_or_initialize_by(event_id: data["event_id"])

      next if transaction.aprobado?
      next if transaction.persisted? && transaction.manually_edited?

      results = CategorizerService.guess(data["detalles"])

      transaction.assign_attributes(
        fecha:        data["fecha_transaccion"],
        monto:        data["monto"],
        moneda:       data["moneda"],
        detalles:     data["detalles"],
        red:          data["red"],
        numero_tarjeta: data["numero_tarjeta"],
        en_cuotas:    data["en_cuotas"].presence || false,
        descripcion_cuota: data["descripcion_cuota"].presence,
        # El servicio de categorización puede usar Regex o incluso una IA local
        categoria:    results[:category],
        sub_categoria:  results[:sub_category],
        # El sentimiento ayuda a separar gastos fijos de impulsivos
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
