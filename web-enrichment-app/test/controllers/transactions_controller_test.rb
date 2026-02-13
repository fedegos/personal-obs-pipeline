require "test_helper"

class TransactionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :transactions

  setup do
    sign_in users(:one)
    @transaction = transactions(:one)
  end

  test "should get index" do
    get transactions_url
    assert_response :success
  end

  test "should update transaction and set manually_edited" do
    @transaction.update!(aprobado: false)
    patch transaction_url(@transaction), params: {
      transaction: { categoria: "Hogar", sub_categoria: "Luz", sentimiento: "Necesario" }
    }, as: :json
    assert_response :success
    @transaction.reload
    assert_equal "Hogar", @transaction.categoria
    assert @transaction.manually_edited?
  end

  test "should not update approved transaction" do
    approved = transactions(:approved)
    patch transaction_url(approved), params: {
      transaction: { categoria: "Otro" }
    }, as: :json
    assert_response :forbidden
  end

  test "should approve transaction" do
    patch approve_transaction_url(@transaction), params: {
      transaction: {
        categoria: @transaction.categoria,
        sub_categoria: @transaction.sub_categoria,
        sentimiento: @transaction.sentimiento
      }
    }
    assert_redirected_to transactions_path
    assert_equal "Aprobado.", flash[:notice]
    @transaction.reload
    assert @transaction.aprobado?
  end

  test "should filter by search query" do
    get transactions_url, params: { q: "Detalle" }
    assert_response :success
  end

  test "should filter by fecha" do
    get transactions_url, params: { fecha: @transaction.fecha.to_date }
    assert_response :success
  end

  test "should filter by monto range" do
    get transactions_url, params: { monto_min: 1, monto_max: 100 }
    assert_response :success
  end

  test "should sort by faciles_primero" do
    get transactions_url, params: { sort: "faciles_primero" }
    assert_response :success
  end

  test "should sort by dificiles_primero" do
    get transactions_url, params: { sort: "dificiles_primero" }
    assert_response :success
  end

  test "should sort by monto_asc" do
    get transactions_url, params: { sort: "monto_asc" }
    assert_response :success
  end

  test "should sort by monto_desc" do
    get transactions_url, params: { sort: "monto_desc" }
    assert_response :success
  end

  test "should filter by categoria" do
    get transactions_url, params: { categoria: "Varios" }
    assert_response :success
  end

  test "approve_similar_preview without params returns empty" do
    get approve_similar_preview_transactions_url
    assert_response :success
  end

  test "approve_similar_preview with params returns matches" do
    get approve_similar_preview_transactions_url, params: {
      categoria: "Categoria",
      sub_categoria: "Sub",
      sentimiento: "Deseo"
    }
    assert_response :success
  end

  test "approve_similar redirects without params" do
    patch approve_similar_transactions_url
    assert_redirected_to transactions_path
  end

  test "approve_similar approves matching transactions" do
    patch approve_similar_transactions_url, params: {
      categoria: "Categoria",
      sentimiento: "Deseo"
    }
    assert_redirected_to transactions_path
  end

  test "approve with turbo_stream format" do
    patch approve_transaction_url(@transaction), params: {
      transaction: {
        categoria: @transaction.categoria,
        sub_categoria: @transaction.sub_categoria,
        sentimiento: @transaction.sentimiento
      }
    }, as: :turbo_stream
    assert_response :success
  end
end
