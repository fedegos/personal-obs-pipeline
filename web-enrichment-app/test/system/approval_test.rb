require "application_system_test_case"

class ApprovalTest < ApplicationSystemTestCase
  fixtures :users, :transactions, :category_rules

  setup do
    @user = users(:one)
    @pending_transaction = transactions(:one)
    sign_in_as(@user)
  end

  test "can approve a single transaction" do
    visit transactions_path

    within("#transaction_#{@pending_transaction.id}") do
      # Asegurar categoría y sentimiento válidos (evita submit deshabilitado por JS)
      fill_in "Categoría", with: "Supermercado"
      select "Deseo ✨", from: "Impacto / Sentimiento"
      click_button "Aprobar Transacción"
    end

    # Transaction should disappear from pending list
    assert_no_selector "#transaction_#{@pending_transaction.id}", wait: 5

    # Verify in database
    @pending_transaction.reload
    assert @pending_transaction.aprobado
  end

  test "approve similar button opens confirmation modal" do
    visit transactions_path

    within("#transaction_#{@pending_transaction.id}") do
      click_button "Aprobar similares"
    end

    # Modal de aprobación en bloque (clase real del overlay)
    assert_selector ".approve-batch-modal-overlay", visible: true
    assert_text "similares"
  end
end
