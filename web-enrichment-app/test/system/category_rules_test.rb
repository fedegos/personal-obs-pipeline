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
end
