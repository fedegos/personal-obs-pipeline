require "test_helper"

class CategoryRulesExportImportServiceTest < ActiveSupport::TestCase
  setup do
    CategorizerService.clear_cache
  end

  test "export returns JSON that parses to array with roots first and children with parent_name" do
    json = CategoryRulesExportImportService.export
    data = JSON.parse(json)

    assert data.is_a?(Array)
    assert data.length >= 2, "fixtures have at least one root and one child"

    roots = data.select { |r| r["parent_name"].nil? }
    children = data.reject { |r| r["parent_name"].nil? }
    assert roots.any?, "at least one root"
    assert children.any?, "at least one child"

    root_names = roots.map { |r| r["name"] }
    children.each do |c|
      assert root_names.include?(c["parent_name"]), "parent_name #{c["parent_name"]} must be a root"
    end

    first = data.first
    assert first.key?("name")
    assert first.key?("pattern")
    assert first.key?("priority")
    assert first.key?("sentimiento") || first["sentimiento"].nil?
    assert first.key?("parent_name")
  end

  test "import with empty array creates nothing" do
    assert_no_difference("CategoryRule.count") do
      CategoryRulesExportImportService.import("[]")
    end
  end

  test "import with one new root rule creates exactly one rule with correct attributes" do
    payload = [ {
      "name" => "NuevaCategoria",
      "pattern" => "NUEVO|nuevo",
      "priority" => 10,
      "sentimiento" => "Necesario",
      "parent_name" => nil
    } ]

    assert_difference("CategoryRule.count", 1) do
      CategoryRulesExportImportService.import(payload.to_json)
    end

    r = CategoryRule.find_by(name: "NuevaCategoria", pattern: "NUEVO|nuevo", parent_id: nil)
    assert_not_nil r
    assert_equal 10, r.priority
    assert_equal "Necesario", r.sentimiento
  end

  test "import with existing rule same attributes does not fail and does not change updated_at" do
    existing = category_rules(:one)
    updated_at_before = existing.updated_at

    payload = [ {
      "name" => existing.name,
      "pattern" => existing.pattern,
      "priority" => existing.priority,
      "sentimiento" => existing.sentimiento,
      "parent_name" => nil
    } ]

    assert_no_difference("CategoryRule.count") do
      CategoryRulesExportImportService.import(payload.to_json)
    end

    existing.reload
    assert_equal updated_at_before.to_i, existing.updated_at.to_i, "updated_at should not change when identical"
  end

  test "import with existing rule different priority updates the rule" do
    existing = category_rules(:one)
    new_priority = (existing.priority || 0) + 100

    payload = [ {
      "name" => existing.name,
      "pattern" => existing.pattern,
      "priority" => new_priority,
      "sentimiento" => existing.sentimiento,
      "parent_name" => nil
    } ]

    assert_no_difference("CategoryRule.count") do
      CategoryRulesExportImportService.import(payload.to_json)
    end

    existing.reload
    assert_equal new_priority, existing.priority
  end

  test "import creates roots first then children" do
    CategoryRule.destroy_all

    payload = [
      { "name" => "Padre", "pattern" => "PADRE", "priority" => 1, "sentimiento" => nil, "parent_name" => nil },
      { "name" => "Hijo", "pattern" => "HIJO", "priority" => 2, "sentimiento" => nil, "parent_name" => "Padre" }
    ]

    CategoryRulesExportImportService.import(payload.to_json)

    padre = CategoryRule.find_by(name: "Padre", parent_id: nil)
    hijo = CategoryRule.find_by(name: "Hijo")
    assert_not_nil padre
    assert_not_nil hijo
    assert_equal padre.id, hijo.parent_id
  end

  test "import with parent_name that does not exist raises with clear message" do
    payload = [ {
      "name" => "Huerfano",
      "pattern" => "X",
      "priority" => 1,
      "sentimiento" => nil,
      "parent_name" => "NoExiste"
    } ]

    err = assert_raises(ArgumentError) do
      CategoryRulesExportImportService.import(payload.to_json)
    end
    assert_match /parent_name.*NoExiste|NoExiste.*parent/i, err.message
  end
end
