require "test_helper"

class TransactionTest < ActiveSupport::TestCase
  fixtures :transactions

  test "fixture is valid" do
    assert transactions(:one).valid?
  end

  test "requires event_id, monto, fecha, detalles" do
    t = Transaction.new
    assert_not t.valid?
    assert t.errors[:event_id].any?
    assert t.errors[:monto].any?
    assert t.errors[:fecha].any?
    assert t.errors[:detalles].any?
  end

  test "event_id must be unique" do
    t = Transaction.new(
      event_id: transactions(:one).event_id,
      monto: 1,
      fecha: Time.current,
      detalles: "x"
    )
    assert_not t.valid?
    assert t.errors[:event_id].any?
  end

  test "scope pendientes returns only unapproved" do
    pendientes = Transaction.pendientes
    assert_includes pendientes, transactions(:one)
    assert_includes pendientes, transactions(:two)
    assert_not_includes pendientes, transactions(:approved)
  end

  test "scope aprobadas returns only approved" do
    aprobadas = Transaction.aprobadas
    assert_includes aprobadas, transactions(:approved)
    assert_not_includes aprobadas, transactions(:one)
  end

  test "SENTIMIENTOS has expected keys" do
    expected = %w[Ahorro Deseo Hormiga Inversión Necesario]
    assert_equal expected, Transaction::SENTIMIENTOS.keys.sort
  end

  test "ready_to_publish? true when aprobado and categoria and sentimiento present" do
    t = transactions(:approved)
    assert t.aprobado
    assert t.categoria.present?
    assert t.sentimiento.present?
    assert t.ready_to_publish?
  end

  test "ready_to_publish? false when not aprobado" do
    t = transactions(:one)
    assert_not t.aprobado
    assert_not t.ready_to_publish?
  end

  test "ready_to_publish? false when categoria blank" do
    t = transactions(:approved)
    t.update_columns(categoria: nil)
    t.reload
    assert_not t.ready_to_publish?
  end

  test "ready_to_publish? false when sentimiento blank" do
    t = transactions(:approved)
    t.update_columns(sentimiento: nil)
    t.reload
    assert_not t.ready_to_publish?
  end

  test "fecha_vencimiento is optional (nullable)" do
    t = Transaction.new(
      event_id: "ev_fv_nil",
      monto: 10,
      fecha: Time.current,
      detalles: "test",
      origen: "definitivo"
    )
    assert t.valid?
    t.fecha_vencimiento = Date.current
    assert t.valid?
  end

  test "origen accepts parcial and definitivo" do
    t = transactions(:approved)
    t.origen = "parcial"
    assert t.valid?
    t.origen = "definitivo"
    assert t.valid?
  end

  test "origen rejects invalid values" do
    t = Transaction.new(
      event_id: "ev_orig_inv",
      monto: 10,
      fecha: Time.current,
      detalles: "test",
      origen: "invalido"
    )
    assert_not t.valid?
    assert t.errors[:origen].any?
  end

  test "origen defaults to definitivo" do
    t = Transaction.create!(
      event_id: "ev_orig_def_#{SecureRandom.hex(8)}",
      monto: 10,
      fecha: Time.current,
      detalles: "test"
    )
    assert_equal "definitivo", t.origen
  end
end
