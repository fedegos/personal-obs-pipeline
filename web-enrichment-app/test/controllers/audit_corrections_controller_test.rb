require "test_helper"

class AuditCorrectionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users, :transactions

  setup do
    sign_in users(:one)
    @transaction = transactions(:approved)
  end

  test "should get index" do
    get audit_corrections_url
    assert_response :success
  end

  test "should get index with query" do
    get audit_corrections_url, params: { query: "aprobada" }
    assert_response :success
  end

  test "should get index with fecha" do
    get audit_corrections_url, params: { fecha: @transaction.fecha.to_date }
    assert_response :success
  end

  test "should get edit" do
    get edit_audit_correction_url(@transaction), as: :turbo_stream
    assert_response :success
  end

  test "should show transaction" do
    get audit_correction_url(@transaction)
    assert_response :success
  end

  test "should update transaction" do
    patch audit_correction_url(@transaction), params: {
      transaction: {
        monto: @transaction.monto,
        categoria: @transaction.categoria,
        sub_categoria: @transaction.sub_categoria,
        sentimiento: @transaction.sentimiento,
        detalles: @transaction.detalles,
        fecha: @transaction.fecha
      }
    }
    assert_redirected_to audit_corrections_path
  end
end
