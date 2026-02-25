# karafka.rb
$stdout.sync = true
require_relative 'config/environment'

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka = { 'bootstrap.servers': ENV.fetch('KAFKA_SERVERS', 'redpanda:29092') }
    config.client_id = 'enrichment_manager'
  end

  routes.draw do
    consumer_group :enrichment_manager_v3 do
      topic :transacciones_raw do
        consumer TransactionsConsumer
        initial_offset "earliest"
      end

      topic :file_results do
        consumer FileResultsConsumer
        initial_offset "earliest"
      end
    end

    # Event Repository: persiste eventos en event_store (DOCS/EVENT-REPOSITORY-DESIGN.md)
    consumer_group :event_store do
      topic :domain_events do
        consumer EventStoreConsumer
        initial_offset "earliest"
      end

      topic :transacciones_clean do
        consumer EventStoreConsumer
        initial_offset "earliest"
      end

      topic :file_results do
        consumer EventStoreConsumer
        initial_offset "earliest"
      end
    end
  end
end

Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
