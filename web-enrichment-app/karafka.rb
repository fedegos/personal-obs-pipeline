# karafka.rb
$stdout.sync = true
require_relative 'config/environment'

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_SERVERS', 'redpanda:29092') }
    config.client_id = 'enrichment_manager'
  end

  routes.draw do
    # OPCIÓN CORRECTA: El grupo envuelve al tópico
    consumer_group :enrichment_manager_v3 do
      topic :transacciones_raw do
        consumer TransactionsConsumer
      end
    end
  end
end

# Suscripción necesaria para ver logs en consola
Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
