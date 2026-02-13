require "application_system_test_case"

class SourceFilesTest < ApplicationSystemTestCase
  fixtures :users, :source_files

  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "visiting upload page shows form" do
    visit upload_path
    assert_text "Ingesta de Datos"
    assert_selector "select[name=\"bank\"]"
    assert_button "Iniciar Pipeline"
  end

  test "selecting a bank updates the dropdown" do
    visit upload_path
    select "VISA", from: "bank"
    assert_field "bank", with: "visa"
  end
end
