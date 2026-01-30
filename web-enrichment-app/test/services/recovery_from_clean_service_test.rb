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
    "red" => "Visa"
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
    assert_equal true, transaction.aprobado
  end
end
