require "application_system_test_case"

class ApprovalTest < ApplicationSystemTestCase
  fixtures :users, :transactions

  setup do
    @user = users(:one)
    @pending_transaction = transactions(:one)
    sign_in_as(@user)
  end

  test "can approve a single transaction" do
    visit transactions_path

    within("#transaction_#{@pending_transaction.id}") do
      click_button "Aprobar"
    end

    # Transaction should disappear from pending list
    assert_no_selector "#transaction_#{@pending_transaction.id}"

    # Verify in database
    @pending_transaction.reload
    assert @pending_transaction.aprobado
  end

  test "approve similar button opens confirmation modal" do
    visit transactions_path

    # Find and click the "Aprobar similares" button for a transaction
    within("#transaction_#{@pending_transaction.id}") do
      click_button "Aprobar similares"
    end

    # Modal should appear
    assert_selector ".modal", visible: true
    assert_text "similares"
  end
end
