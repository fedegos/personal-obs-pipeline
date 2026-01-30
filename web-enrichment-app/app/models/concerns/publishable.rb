# app/models/concerns/publishable.rb
module Publishable
  extend ActiveSupport::Concern

  def publish_clean_event
    # El payload usa los atributos del objeto actual (self)
    payload = {
      event_id:      event_id,
      fecha:         fecha.iso8601,
      monto:         monto.to_f,
      moneda:        moneda,
      detalles:      detalles,
      categoria:     categoria,
      sub_categoria: sub_categoria,
      sentimiento:   sentimiento,
      red:           red
    }

    begin
      Karafka.producer.produce_async(
        topic: "transacciones_clean",
        payload: payload.to_json,
        key: event_id
      )
    rescue => e
      Rails.logger.error "❌ Error publicando en Kafka Clean (ID: #{event_id}): #{e.message}"
    end
  end
end
