require "test_helper"

class CategoryRulesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category_rule = category_rules(:one)
  end

  test "should get index" do
    get category_rules_url
    assert_response :success
  end

  test "should get new" do
    get new_category_rule_url
    assert_response :success
  end

  test "should create category_rule" do
    assert_difference("CategoryRule.count") do
      post category_rules_url, params: { category_rule: { name: @category_rule.name, parent_id: @category_rule.parent_id, pattern: @category_rule.pattern, priority: @category_rule.priority } }
    end

    assert_redirected_to category_rule_url(CategoryRule.last)
  end

  test "should show category_rule" do
    get category_rule_url(@category_rule)
    assert_response :success
  end

  test "should get edit" do
    get edit_category_rule_url(@category_rule)
    assert_response :success
  end

  test "should update category_rule" do
    patch category_rule_url(@category_rule), params: { category_rule: { name: @category_rule.name, parent_id: @category_rule.parent_id, pattern: @category_rule.pattern, priority: @category_rule.priority } }
    assert_redirected_to category_rule_url(@category_rule)
  end

  test "should destroy category_rule" do
    assert_difference("CategoryRule.count", -1) do
      delete category_rule_url(@category_rule)
    end

    assert_redirected_to category_rules_url
  end
end
