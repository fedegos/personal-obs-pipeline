require "test_helper"
require "ostruct"

class TransactionsConsumerTest < ActiveSupport::TestCase
  fixtures :transactions

  test "consume creates or updates transaction from message payload" do
    payload = {
      "event_id"           => "test_event_#{SecureRandom.hex(4)}",
      "fecha_transaccion"  => 1.day.ago.to_date,
      "monto"              => 99.99,
      "moneda"             => "pesos",
      "detalles"           => "Compra test",
      "red"                => "Visa",
      "numero_tarjeta"     => "XXXX 3689",
      "en_cuotas"          => true,
      "descripcion_cuota"  => "2/3"
    }

    fake_message = OpenStruct.new(payload: payload)
    consumer = TransactionsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }

    original_guess = CategorizerService.method(:guess)
    CategorizerService.define_singleton_method(:guess) { |_| { category: "Hogar", sub_category: "Luz", sentimiento: "Necesario" } }

    begin
      assert_difference("Transaction.count", 1) do
        consumer.consume
      end

      t = Transaction.find_by(event_id: payload["event_id"])
      assert_not_nil t
      assert_equal payload["monto"], t.monto.to_f
      assert_equal payload["detalles"], t.detalles
      assert_equal "Hogar", t.categoria
      assert_equal "Luz", t.sub_categoria
      assert_equal "Necesario", t.sentimiento
      assert_equal "XXXX 3689", t.numero_tarjeta
      assert_equal true, t.en_cuotas?
      assert_equal "2/3", t.descripcion_cuota
      assert_equal false, t.aprobado
      assert_equal "definitivo", t.origen
    ensure
      CategorizerService.define_singleton_method(:guess) { |*args| original_guess.call(*args) }
    end
  end

  test "consume skips message when transaction already approved" do
    tx = transactions(:approved)
    payload = {
      "event_id"          => tx.event_id,
      "fecha_transaccion"  => tx.fecha,
      "monto"              => 1.0,
      "moneda"             => "pesos",
      "detalles"           => tx.detalles,
      "red"                => tx.red,
      "numero_tarjeta"     => nil
    }

    fake_message = OpenStruct.new(payload: payload)
    consumer = TransactionsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }

    assert_no_difference("Transaction.count") do
      consumer.consume
    end

    tx.reload
    assert tx.aprobado
    assert_equal 50.00, tx.monto.to_f
  end

  test "consume persists fecha_vencimiento and origen from payload" do
    payload = {
      "event_id"           => "test_event_fv_#{SecureRandom.hex(4)}",
      "fecha_transaccion"  => 1.day.ago.to_date,
      "monto"              => 99.99,
      "moneda"             => "pesos",
      "detalles"           => "Compra test",
      "red"                => "Visa",
      "fecha_vencimiento"  => "2026-01-31",
      "origen"             => "parcial"
    }

    fake_message = OpenStruct.new(payload: payload)
    consumer = TransactionsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }

    original_guess = CategorizerService.method(:guess)
    CategorizerService.define_singleton_method(:guess) { |_| { category: "Hogar", sub_category: "Luz", sentimiento: "Necesario" } }

    begin
      assert_difference("Transaction.count", 1) { consumer.consume }
      t = Transaction.find_by(event_id: payload["event_id"])
      assert_equal Date.parse("2026-01-31"), t.fecha_vencimiento
      assert_equal "parcial", t.origen
    ensure
      CategorizerService.define_singleton_method(:guess) { |*args| original_guess.call(*args) }
    end
  end
end
