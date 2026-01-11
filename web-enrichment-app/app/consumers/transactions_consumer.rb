# app/consumers/transactions_consumer.rb
class TransactionsConsumer < ApplicationConsumer
  def consume
    # Procesamos en bloque para mayor eficiencia en Kafka
    messages.each do |message|
      data = message.payload
      
      # Buscamos por event_id (el hash generado en Python)
      transaction = Transaction.find_or_initialize_by(event_id: data['event_id'])
      
      # Lógica de seguridad: Si ya está aprobada, ignoramos el mensaje de Kafka
      # Esto evita que una re-ingesta de un CSV viejo arruine tus datos curados
      next if transaction.aprobado?

      transaction.assign_attributes(
        fecha:        data['fecha_transaccion'],
        monto:        data['monto'],
        moneda:       data['moneda'],
        detalles:     data['detalles'],
        red:          data['red'],
        # El servicio de categorización puede usar Regex o incluso una IA local
        categoria:    CategorizerService.guess(data["detalles"]),
        sub_categoria:  CategorizerService.guess_sub_category(data['detalles']),
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
