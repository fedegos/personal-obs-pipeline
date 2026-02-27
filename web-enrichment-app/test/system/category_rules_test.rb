require "application_system_test_case"

class CategoryRulesTest < ApplicationSystemTestCase
  fixtures :users, :category_rules

  setup do
    @user = users(:one)
    @rule = category_rules(:one)
    sign_in_as(@user)
  end

  test "visiting category rules index shows rules" do
    visit category_rules_path

    assert_text "Reglas"
    assert_text @rule.name
  end

  test "can create a new category rule" do
    visit category_rules_path
    click_link "Nueva Regla"

    fill_in "category_rule[name]", with: "Test Rule"
    fill_in "category_rule[pattern]", with: "TEST|test"
    fill_in "category_rule[priority]", with: "1"
    click_button "Guardar Regla"

    assert_text "Test Rule"
  end

  test "can edit an existing rule" do
    visit edit_category_rule_path(@rule)

    fill_in "category_rule[name]", with: "Regla Editada"
    click_button "Guardar Regla"

    assert_text "Regla actualizada correctamente"
  end

  test "can filter rules by sentimiento" do
    visit category_rules_path

    select "Deseo ✨", from: "filter_sentimiento"

    assert_text @rule.name
  end

  test "can export rules" do
    visit category_rules_path

    click_link "Exportar"

    # Export triggers download; page may stay or redirect
    assert_text "Motor de Reglas"
  end

  test "adding pattern to rule updates transaction suggestions" do
    # Crear una transacción con un detalle único que no matchea ninguna regla
    unique_detail = "ZZUNIQUE_DETAIL_#{SecureRandom.hex(4)}"
    transaction = Transaction.create!(
      event_id: SecureRandom.uuid,
      fecha: Date.today,
      monto: 100,
      detalles: unique_detail,
      moneda: "pesos",
      aprobado: false
    )

    # Verificar que inicialmente no tiene categoría (Varios)
    result_before = CategorizerService.guess(unique_detail)
    assert_equal "Varios", result_before[:category], "Antes de modificar la regla, debe ser Varios"

    # Ir a transacciones y verificar que muestra "Varios" o sin categoría
    visit transactions_path
    assert_text unique_detail

    # Ahora modificar una regla existente para que matchee este detalle
    @rule.update!(pattern: "#{@rule.pattern}|#{unique_detail}")

    # Verificar que el servicio ahora devuelve la categoría correcta
    result_after = CategorizerService.guess(unique_detail)
    assert_equal @rule.name, result_after[:category], "Después de modificar la regla, debe matchear"

    # Refrescar la página de transacciones
    visit transactions_path

    # La transacción debe mostrar la nueva categoría sugerida (UI muestra en mayúsculas)
    within("#transaction_#{transaction.id}") do
      assert_text @rule.name.upcase
    end

    # Limpiar
    transaction.destroy
    @rule.update!(pattern: @rule.pattern.sub("|#{unique_detail}", ""))
  end
end
