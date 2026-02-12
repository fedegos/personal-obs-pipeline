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

    assert_text "Transacciones Pendientes"
    assert_text @pending_transaction.detalles
  end

  test "can filter transactions by search term" do
    visit transactions_path

    fill_in "Buscar", with: "Detalle uno"
    
    assert_text "Detalle uno"
  end

  test "can see transaction details in card" do
    visit transactions_path

    within("#transaction_#{@pending_transaction.id}") do
      assert_text @pending_transaction.detalles
    end
  end
end
