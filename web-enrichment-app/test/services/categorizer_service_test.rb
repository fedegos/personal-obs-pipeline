require "test_helper"

class CategorizerServiceTest < ActiveSupport::TestCase
  fixtures :category_rules

  setup do
    CategorizerService.clear_cache
  end

  test "guess returns default for blank text" do
    result = CategorizerService.guess("")
    assert_equal "Varios", result[:category]
    assert_nil result[:sub_category]
    assert_nil result[:sentimiento]

    result = CategorizerService.guess(nil)
    assert_equal "Varios", result[:category]
    assert_nil result[:sub_category]
  end

  test "guess returns default when no rule matches" do
    result = CategorizerService.guess("TextoQueNoCoincideConNingunaRegla123")
    assert_equal "Varios", result[:category]
    assert_nil result[:sub_category]
    assert_nil result[:sentimiento]
  end

  test "guess returns category and sub_category when a rule matches" do
    # Fixtures: one (root Supermercado), two (hijo Coto) con pattern COTO|Coto
    result = CategorizerService.guess("Compra en COTO")
    assert result[:category].present?
    assert_equal "Supermercado", result[:category]
    assert_equal "Coto", result[:sub_category]
    assert result.key?(:sentimiento)
  end

  test "clear_cache resets rules" do
    CategorizerService.guess("x")
    CategorizerService.clear_cache
    # No debe levantar; tras clear_cache la siguiente llamada recarga reglas
    result = CategorizerService.guess("y")
    assert result.key?(:category)
  end

  # Reproduce: tras cambiar una regla en DB, guess() debe devolver el resultado actualizado.
  # update_all evita callbacks → clear_cache no corre → simula otro proceso con caché obsoleto.
  test "guess returns updated result when rules change in DB without callbacks" do
    CategorizerService.clear_cache
    # Fixtures: two (Coto) matchea COTO; devuelve Supermercado/Coto
    result_before = CategorizerService.guess("Compra en COTO")
    assert_equal "Supermercado", result_before[:category]
    assert_equal "Coto", result_before[:sub_category]

    # Cambiar la regla en DB sin callbacks (simula otro proceso que modificó la DB)
    CategoryRule.where(id: category_rules(:two).id).update_all(pattern: "DIA|Dia")

    # Con caché en proceso, guess() seguiría devolviendo Coto. Debe devolver nil (reglas frescas).
    result_after = CategorizerService.guess("Compra en COTO")
    # one (Supermercado) tiene pattern COTO|Coto → matchea como raíz → sub_category nil
    assert_equal "Supermercado", result_after[:category]
    assert_nil result_after[:sub_category], "Debe devolver sub_category nil; Coto ya no matchea"
  end
end
