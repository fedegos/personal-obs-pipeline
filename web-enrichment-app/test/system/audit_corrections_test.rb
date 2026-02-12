require "application_system_test_case"

class AuditCorrectionsTest < ApplicationSystemTestCase
  fixtures :users, :transactions

  setup do
    @user = users(:one)
    @approved_transaction = transactions(:approved)
    sign_in_as(@user)
  end

  test "visiting audit corrections index shows approved transactions" do
    visit audit_corrections_path

    assert_text "Auditoria"
    assert_text @approved_transaction.detalles
  end

  test "can edit an approved transaction" do
    visit edit_audit_correction_path(@approved_transaction)

    fill_in "transaction[categoria]", with: "Categoria Corregida"
    click_button "Guardar"

    @approved_transaction.reload
    assert_equal "Categoria Corregida", @approved_transaction.categoria
  end

  test "can navigate to next transaction" do
    visit edit_audit_correction_path(@approved_transaction)

    # Should have navigation buttons
    assert_selector "a", text: /Siguiente|Next/i
  end

  test "can navigate to previous transaction" do
    visit edit_audit_correction_path(@approved_transaction)

    # Should have navigation buttons
    assert_selector "a", text: /Anterior|Prev/i
  end
end
