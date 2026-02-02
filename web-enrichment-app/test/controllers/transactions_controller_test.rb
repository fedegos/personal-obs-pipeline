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
