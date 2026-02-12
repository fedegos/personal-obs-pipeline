# frozen_string_literal: true

require "test_helper"

class RecoveryFromCleanServiceTest < ActiveSupport::TestCase
  PAYLOAD_CLEAN = {
    "event_id" => "evt-recovery-test-001",
    "fecha" => "2025-01-15T12:00:00Z",
    "monto" => -1500.50,
    "moneda" => "ARS",
    "detalles" => "Supermercado Test",
    "categoria" => "Alimentos",
    "sub_categoria" => "Supermercado",
    "sentimiento" => "Necesario",
    "red" => "Visa",
    "numero_tarjeta" => "XXXX 3689",
    "en_cuotas" => true,
    "descripcion_cuota" => "3/6"
  }.freeze

  test "apply_clean_message creates new Transaction with correct attributes and aprobado true" do
    assert_nil Transaction.find_by(event_id: PAYLOAD_CLEAN["event_id"])

    transaction = RecoveryFromCleanService.apply_clean_message(PAYLOAD_CLEAN)

    assert transaction.persisted?
    assert_equal PAYLOAD_CLEAN["event_id"], transaction.event_id
    assert_equal PAYLOAD_CLEAN["detalles"], transaction.detalles
    assert_equal PAYLOAD_CLEAN["categoria"], transaction.categoria
    assert_equal PAYLOAD_CLEAN["sentimiento"], transaction.sentimiento
    assert_equal PAYLOAD_CLEAN["red"], transaction.red
    assert_equal PAYLOAD_CLEAN["numero_tarjeta"], transaction.numero_tarjeta
    assert_equal PAYLOAD_CLEAN["en_cuotas"], transaction.en_cuotas?
    assert_equal PAYLOAD_CLEAN["descripcion_cuota"], transaction.descripcion_cuota
    assert transaction.aprobado?
    assert_in_delta(-1500.50, transaction.monto.to_f, 0.01)
    assert transaction.fecha.present?
  end

  test "apply_clean_message updates existing Transaction and sets aprobado true" do
    existing = Transaction.create!(
      event_id: PAYLOAD_CLEAN["event_id"],
      fecha: 1.year.ago,
      monto: -100,
      detalles: "Viejo",
      aprobado: false
    )

    transaction = RecoveryFromCleanService.apply_clean_message(PAYLOAD_CLEAN)

    assert_equal existing.id, transaction.id
    transaction.reload
    assert_equal PAYLOAD_CLEAN["detalles"], transaction.detalles
    assert_equal PAYLOAD_CLEAN["categoria"], transaction.categoria
    assert transaction.aprobado?
  end

  test "apply_clean_message_to assigns attributes without saving" do
    transaction = Transaction.new

    RecoveryFromCleanService.apply_clean_message_to(transaction, PAYLOAD_CLEAN)

    assert transaction.new_record?
    assert_equal PAYLOAD_CLEAN["event_id"], transaction.event_id
    assert_equal PAYLOAD_CLEAN["detalles"], transaction.detalles
    assert_equal PAYLOAD_CLEAN["numero_tarjeta"], transaction.numero_tarjeta
    assert_equal PAYLOAD_CLEAN["en_cuotas"], transaction.en_cuotas?
    assert_equal PAYLOAD_CLEAN["descripcion_cuota"], transaction.descripcion_cuota
    assert_equal true, transaction.aprobado
  end

  test "apply_clean_message handles Time object for fecha" do
    payload = PAYLOAD_CLEAN.merge("event_id" => "evt-time-fecha", "fecha" => Time.zone.now)
    transaction = RecoveryFromCleanService.apply_clean_message(payload)
    assert transaction.persisted?
    assert transaction.fecha.present?
  end

  test "apply_clean_message handles en_cuotas nil" do
    payload = PAYLOAD_CLEAN.merge("event_id" => "evt-nil-cuotas", "en_cuotas" => nil)
    transaction = RecoveryFromCleanService.apply_clean_message(payload)
    assert transaction.persisted?
    assert_equal false, transaction.en_cuotas?
  end
end
