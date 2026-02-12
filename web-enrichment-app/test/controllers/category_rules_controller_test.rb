require "test_helper"

class CategoryRulesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :category_rules

  setup do
    sign_in users(:one)
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
    leaf = category_rules(:two)
    assert_difference("CategoryRule.count", -1) do
      delete category_rule_url(leaf)
    end
    assert_redirected_to category_rules_url
  end

  test "should get export as JSON attachment" do
    get export_category_rules_url
    assert_response :success
    assert_equal "application/json", response.media_type
    assert response.headers["Content-Disposition"].to_s.include?("attachment")
    data = JSON.parse(response.body)
    assert data.is_a?(Array)
  end

  test "should import valid JSON and redirect with notice" do
    json = [ { "name" => "ImpCat", "pattern" => "IMP", "priority" => 1, "sentimiento" => nil, "parent_name" => nil } ].to_json
    post import_category_rules_url, params: { json: json }
    assert_redirected_to category_rules_url
    assert_equal "Reglas importadas correctamente.", flash[:notice]
    assert CategoryRule.exists?(name: "ImpCat", pattern: "IMP", parent_id: nil)
  end

  test "import without file or json redirects with alert" do
    post import_category_rules_url
    assert_redirected_to category_rules_url
    assert_match /adjuntar|contenido/, flash[:alert].to_s
  end

  test "index filters by sentimiento" do
    get category_rules_url, params: { sentimiento: "Deseo" }
    assert_response :success
  end

  test "index filters by blank sentimiento" do
    get category_rules_url, params: { sentimiento: "_blank" }
    assert_response :success
  end

  test "create with turbo_stream format" do
    assert_difference("CategoryRule.count") do
      post category_rules_url, params: { 
        category_rule: { name: "New Rule", pattern: "NEW", priority: 1 } 
      }, as: :turbo_stream
    end
    assert_response :success
  end

  test "create with invalid data renders new" do
    post category_rules_url, params: { category_rule: { name: "", pattern: "X", priority: 1 } }
    assert_response :unprocessable_entity
  end

  test "update with turbo_stream format" do
    patch category_rule_url(@category_rule), params: { 
      category_rule: { name: "Updated Name" } 
    }, as: :turbo_stream
    assert_response :success
  end

  test "destroy with turbo_stream format" do
    leaf = category_rules(:two)
    assert_difference("CategoryRule.count", -1) do
      delete category_rule_url(leaf), as: :turbo_stream
    end
    assert_response :success
  end

  test "import with invalid JSON redirects with alert" do
    post import_category_rules_url, params: { json: "not valid json" }
    assert_redirected_to category_rules_url
    assert_match /JSON/, flash[:alert]
  end

  test "new responds to turbo_stream" do
    get new_category_rule_url, as: :turbo_stream
    assert_response :success
  end

  test "edit responds to turbo_stream" do
    get edit_category_rule_url(@category_rule), as: :turbo_stream
    assert_response :success
  end

  test "show responds to turbo_stream" do
    get category_rule_url(@category_rule), as: :turbo_stream
    assert_response :success
  end
end
