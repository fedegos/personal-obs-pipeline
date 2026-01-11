# karafka.rb
require_relative 'config/environment'

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_SERVERS', 'redpanda:29092') }
    config.client_id = 'enrichment_manager'
  end

  routes.draw do
    topic :transacciones_raw do
      # CAMBIO CLAVE: Usar comillas para evitar el NameError al arrancar
      consumer "TransactionsConsumer"
    end
  end
end
