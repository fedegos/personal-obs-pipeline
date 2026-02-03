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
end
