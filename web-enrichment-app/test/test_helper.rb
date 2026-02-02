ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Evitar que los tests escriban a los tópicos de Kafka de desarrollo.
# DomainEventPublishable y Publishable publican en domain_events/transacciones_clean;
# con este stub, los mensajes se descartan. Tests que necesiten capturar payloads
# (PublishableTest, ExcelUploaderServiceTest) pueden sobrescribir temporalmente.
null_producer = Object.new
null_producer.define_singleton_method(:produce_async) { |**_| }
Karafka.define_singleton_method(:producer) { null_producer }

module ActiveSupport
  class TestCase
    # Run tests in parallel. Menos workers = menos contención en DB; más workers = más CPU.
    # En Docker, number_of_processors puede ser alto → pruebas más lentas. Ajustar con PARALLEL_WORKERS=2 si hace falta.
    workers = ENV["PARALLEL_WORKERS"]
    parallelize(workers: workers.present? ? workers.to_i : :number_of_processors)

    # Fixtures se declaran por archivo (cada test solo carga lo que usa). Ver DOCS/TEST-PROFILING.md.

    # Add more helper methods to be used by all tests here...
  end
end
