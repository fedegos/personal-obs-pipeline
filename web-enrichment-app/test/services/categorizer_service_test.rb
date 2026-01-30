require "test_helper"

class CategorizerServiceTest < ActiveSupport::TestCase
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
end
