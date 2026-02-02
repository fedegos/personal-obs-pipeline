# frozen_string_literal: true

require "test_helper"

class TransactionCardViewTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :transactions

  test "transactions index shows moneda badge when transaction has moneda" do
    sign_in users(:one)
    tx = transactions(:one)
    tx.update!(moneda: "pesos")

    get transactions_url

    assert_response :success
    assert_select ".badge-moneda", text: /pesos/
  end

  test "transactions index shows cuotas badge when transaction is en_cuotas" do
    sign_in users(:one)

    get transactions_url

    assert_response :success
    assert_select ".badge-cuotas", text: /Cuota 2\/6/
  end

  test "transactions index shows numero_tarjeta badge when present" do
    sign_in users(:one)
    tx = transactions(:one)
    tx.update!(numero_tarjeta: "XXXX 3689")

    get transactions_url

    assert_response :success
    assert_select ".badge-card-number", text: /XXXX 3689/
  end
end
