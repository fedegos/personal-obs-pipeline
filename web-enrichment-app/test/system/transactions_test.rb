require "application_system_test_case"

class TransactionsTest < ApplicationSystemTestCase
  fixtures :users, :transactions

  setup do
    @user = users(:one)
    @pending_transaction = transactions(:one)
    sign_in_as(@user)
  end

  test "visiting transactions index shows pending transactions" do
    visit transactions_path

    assert_text "Gastos Pendientes"
    assert_text @pending_transaction.detalles
  end

  test "can filter transactions by search term" do
    visit transactions_path

    fill_in "q", with: "Detalle uno"

    assert_text "Detalle uno"
  end

  test "can see transaction details in card" do
    visit transactions_path

    within("#transaction_#{@pending_transaction.id}") do
      assert_text @pending_transaction.detalles
    end
  end

  test "can load more transactions without leaving the page" do
    Transaction.where(aprobado: false).update_all(aprobado: true)
    60.times { |i| create_pending_transaction(i, detalles: "Lote #{i}") }

    visit transactions_path

    assert_selector "#transactions-container .transaction-card", count: 50
    assert_selector "button", text: "Cargar más"

    click_button "Cargar más"
    assert_selector "#transactions-container .transaction-card", minimum: 51
  end

  test "changing filters resets infinite scroll results" do
    Transaction.where(aprobado: false).update_all(aprobado: true)
    60.times { |i| create_pending_transaction(i, detalles: "General #{i}") }
    create_pending_transaction(999, detalles: "SoloUnicoXYZ")

    visit transactions_path

    click_button "Cargar más"
    assert_selector "#transactions-container .transaction-card", minimum: 51

    fill_in "q", with: "SoloUnicoXYZ"
    assert_text "SoloUnicoXYZ"
    assert_selector "#transactions-container .transaction-card", count: 1
  end

  private

  def create_pending_transaction(index, detalles:)
    Transaction.create!(
      event_id: "sys_scroll_event_#{index}_#{SecureRandom.hex(4)}",
      fecha: Time.zone.parse("2026-02-01") + index.minutes,
      monto: index + 10,
      moneda: "pesos",
      detalles: detalles,
      categoria: "Categoria",
      sub_categoria: "Sub",
      sentimiento: "Deseo",
      red: "Visa",
      origen: "definitivo",
      aprobado: false
    )
  end
end
