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

    assert_text "Correcciones"
    assert_text @approved_transaction.detalles
  end

  test "can edit an approved transaction" do
    visit audit_corrections_path
    within("#transaction_#{@approved_transaction.id}") { click_link "Corregir Registro" }

    within("#modal-overlay") do
      fill_in "Categoría", with: "Categoria Corregida"
      click_button "Guardar Cambios"
    end

    @approved_transaction.reload
    assert_equal "Categoria Corregida", @approved_transaction.categoria
  end

  test "can navigate to next transaction" do
    visit audit_corrections_path
    within("#transaction_#{@approved_transaction.id}") { click_link "Corregir Registro" }

    within("#modal-overlay") do
      assert_selector "a", text: /Siguiente|Next/i
    end
  end

  test "can navigate to previous transaction" do
    visit audit_corrections_path
    within("#transaction_#{@approved_transaction.id}") { click_link "Corregir Registro" }

    within("#modal-overlay") do
      assert_selector "a", text: /Anterior|Prev/i
    end
  end
end
