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
    click_link "Nueva regla"

    fill_in "category_rule[name]", with: "Test Rule"
    fill_in "category_rule[pattern]", with: "TEST|test"
    click_button "Guardar"

    assert_text "Test Rule"
  end

  test "can edit an existing rule" do
    visit edit_category_rule_path(@rule)

    fill_in "category_rule[name]", with: "Regla Editada"
    click_button "Guardar"

    assert_text "Regla Editada"
  end

  test "can filter rules by search" do
    visit category_rules_path

    fill_in "Buscar", with: @rule.name

    assert_text @rule.name
  end

  test "can export rules" do
    visit category_rules_path

    click_link "Exportar"

    # Should download JSON or show export
    assert_current_path export_category_rules_path
  end
end
