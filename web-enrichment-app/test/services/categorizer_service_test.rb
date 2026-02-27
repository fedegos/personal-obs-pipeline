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

  # Reproduce: tras cambiar el parent_id (categoría) de una regla, guess() debe devolver
  # la nueva categoría padre, no la anterior.
  test "guess returns updated category when parent_id changes" do
    CategorizerService.clear_cache

    # Crear una nueva categoría raíz "Hogar"
    hogar = CategoryRule.create!(name: "Hogar", pattern: "HOGAR_NO_MATCH", priority: 1)

    # Fixtures: two (Coto) pertenece a one (Supermercado)
    result_before = CategorizerService.guess("Compra en COTO")
    assert_equal "Supermercado", result_before[:category]
    assert_equal "Coto", result_before[:sub_category]

    # Cambiar la categoría padre de "Coto" a "Hogar" usando update (con callbacks)
    coto_rule = category_rules(:two)
    coto_rule.update!(parent_id: hogar.id)

    # El servicio debe devolver "Hogar" como categoría, no "Supermercado"
    result_after = CategorizerService.guess("Compra en COTO")
    assert_equal "Hogar", result_after[:category], "Categoría debe ser Hogar después del cambio de parent_id"
    assert_equal "Coto", result_after[:sub_category]
  end

  # Reproduce: cambiar parent_id usando update_all (sin callbacks) también debe refrescar
  # porque el caché se invalida por updated_at
  test "guess returns updated category when parent_id changes without callbacks" do
    CategorizerService.clear_cache

    # Crear una nueva categoría raíz "Entretenimiento"
    entretenimiento = CategoryRule.create!(name: "Entretenimiento", pattern: "ENTRET_NO_MATCH", priority: 1)

    result_before = CategorizerService.guess("Compra en COTO")
    assert_equal "Supermercado", result_before[:category]
    assert_equal "Coto", result_before[:sub_category]

    # Cambiar parent_id sin callbacks (simula edición desde otro proceso)
    # Importante: también actualizamos updated_at para que el caché se invalide
    CategoryRule.where(id: category_rules(:two).id).update_all(
      parent_id: entretenimiento.id,
      updated_at: Time.current
    )

    result_after = CategorizerService.guess("Compra en COTO")
    assert_equal "Entretenimiento", result_after[:category], "Categoría debe ser Entretenimiento después del cambio"
    assert_equal "Coto", result_after[:sub_category]
  end

  # Bug: cuando se cambia el nombre de una categoría raíz, las subcategorías
  # deben devolver el nuevo nombre de la categoría padre.
  test "guess returns updated parent name when parent name changes" do
    CategorizerService.clear_cache

    result_before = CategorizerService.guess("Compra en COTO")
    assert_equal "Supermercado", result_before[:category]
    assert_equal "Coto", result_before[:sub_category]

    # Cambiar el nombre de la categoría raíz
    supermercado = category_rules(:one)
    supermercado.update!(name: "Mercado")

    result_after = CategorizerService.guess("Compra en COTO")
    assert_equal "Mercado", result_after[:category], "Categoría debe reflejar el nuevo nombre del padre"
    assert_equal "Coto", result_after[:sub_category]
  end

  # Verifica que update_all SIN updated_at explícito aún invalida el caché
  # porque Rails auto-actualiza updated_at en update_all.
  test "guess updates when parent_id changes via update_all even without explicit updated_at" do
    CategorizerService.clear_cache

    hogar = CategoryRule.create!(name: "Hogar", pattern: "HOGAR_NO_MATCH", priority: 1)

    # Poblar el caché
    result_before = CategorizerService.guess("Compra en COTO")
    assert_equal "Supermercado", result_before[:category]

    # Cambiar parent_id via update_all
    CategoryRule.where(id: category_rules(:two).id).update_all(parent_id: hogar.id)

    # El caché se invalida porque update_all actualiza updated_at automáticamente
    result_after = CategorizerService.guess("Compra en COTO")
    assert_equal "Hogar", result_after[:category],
      "Categoría debe actualizarse a Hogar"
  end

  # Bug: cuando se agrega un nuevo patrón a una regla existente, las transacciones
  # que antes no matcheaban ahora deben recibir la categoría correcta.
  test "guess matches new pattern added to existing rule" do
    CategorizerService.clear_cache

    # Antes: "NUEVO_COMERCIO" no matchea ninguna regla
    result_before = CategorizerService.guess("Compra en NUEVO_COMERCIO")
    assert_equal "Varios", result_before[:category]
    assert_nil result_before[:sub_category]

    # Agregar NUEVO_COMERCIO al pattern de la regla "Coto"
    coto_rule = category_rules(:two)
    coto_rule.update!(pattern: "COTO|Coto|NUEVO_COMERCIO")

    # Después: debe matchear Supermercado/Coto
    result_after = CategorizerService.guess("Compra en NUEVO_COMERCIO")
    assert_equal "Supermercado", result_after[:category],
      "Debe matchear Supermercado después de agregar el patrón"
    assert_equal "Coto", result_after[:sub_category]
  end

  # Bug específico: el caché debe invalidarse cuando se modifica el pattern
  # de una regla, incluso si el updated_at tiene precisión de milisegundos.
  test "guess invalidates cache when pattern changes rapidly" do
    CategorizerService.clear_cache

    # Poblar caché con una búsqueda
    CategorizerService.guess("Compra en COTO")

    # Modificar pattern inmediatamente
    coto_rule = category_rules(:two)
    old_pattern = coto_rule.pattern
    coto_rule.update!(pattern: "COTO|Coto|RAPIDO_TEST")

    # Buscar el nuevo patrón
    result = CategorizerService.guess("Compra en RAPIDO_TEST")
    assert_equal "Supermercado", result[:category]
    assert_equal "Coto", result[:sub_category]

    # Restaurar
    coto_rule.update!(pattern: old_pattern)
  end
end
