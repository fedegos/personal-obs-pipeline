require "test_helper"

class CategoryRuleTest < ActiveSupport::TestCase
  fixtures :category_rules

  test "fixture one is valid" do
    assert category_rules(:one).valid?
  end

  test "fixture two is valid and belongs to one" do
    two = category_rules(:two)
    assert two.valid?
    assert_equal category_rules(:one), two.parent
    assert category_rules(:one).children.include?(two)
  end

  test "requires name and pattern" do
    rule = CategoryRule.new(priority: 1)
    assert_not rule.valid?
    assert rule.errors[:name].any?
    assert rule.errors[:pattern].any?

    rule.name = "Test"
    rule.pattern = ".*"
    assert rule.valid?
  end

  test "priority must be integer" do
    rule = CategoryRule.new(name: "X", pattern: "x", priority: 1.5)
    assert_not rule.valid?
    assert rule.errors[:priority].any?

    rule.priority = 1
    assert rule.valid?
  end

  test "sentimiento must be in SENTIMIENTOS keys or nil" do
    rule = CategoryRule.new(name: "X", pattern: "x", priority: 1, sentimiento: "Necesario")
    assert rule.valid?

    rule.sentimiento = "Invalido"
    assert_not rule.valid?
    assert rule.errors[:sentimiento].any?

    rule.sentimiento = nil
    assert rule.valid?
  end

  test "scope roots returns only rules without parent" do
    roots = CategoryRule.roots
    assert_includes roots, category_rules(:one)
    assert_not_includes roots, category_rules(:two)
  end

  test "destroying parent destroys children" do
    one = category_rules(:one)
    two = category_rules(:two)
    assert_difference("CategoryRule.count", -2) do
      one.destroy
    end
    assert_raises(ActiveRecord::RecordNotFound) { two.reload }
  end
end
