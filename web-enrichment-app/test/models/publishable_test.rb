# frozen_string_literal: true

require "test_helper"

class PublishableTest < ActiveSupport::TestCase
  fixtures :transactions

  # Transaction incluye Publishable. Verificamos que el payload incluye numero_tarjeta,
  # en_cuotas, descripcion_cuota. Usamos un fake producer para capturar sin Kafka.
  test "publish_clean_event sends numero_tarjeta, en_cuotas, descripcion_cuota in payload" do
    tx = transactions(:approved)
    tx.update!(
      numero_tarjeta: "XXXX 3689",
      en_cuotas: true,
      descripcion_cuota: "3/6"
    )

    payload_captured = nil
    fake_producer = Object.new
    fake_producer.define_singleton_method(:produce_async) { |topic:, payload:, key:| payload_captured = JSON.parse(payload) }

    original_producer = Karafka.method(:producer)
    Karafka.define_singleton_method(:producer) { fake_producer }

    begin
      tx.publish_clean_event
    ensure
      Karafka.define_singleton_method(:producer) { |*args| original_producer.call(*args) }
    end

    assert_not_nil payload_captured
    assert_equal "XXXX 3689", payload_captured["numero_tarjeta"]
    assert_equal true, payload_captured["en_cuotas"]
    assert_equal "3/6", payload_captured["descripcion_cuota"]
  end
end
