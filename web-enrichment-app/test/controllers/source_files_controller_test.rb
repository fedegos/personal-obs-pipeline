require "test_helper"

class SourceFilesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in users(:one)
  end

  test "should get index" do
    get upload_url
    assert_response :success
  end

  test "create with invalid bank redirects with alert" do
    post source_files_url, params: { bank: "invalid_bank" }
    assert_redirected_to upload_path
    assert_equal "El banco seleccionado no es válido.", flash[:alert]
  end

  test "create with valid bank without file when file required redirects with alert" do
    post source_files_url, params: { bank: "bbva" }
    assert_redirected_to upload_path
    assert_match /Debe adjuntar un archivo/, flash[:alert]
  end

  test "create with valid bank and file succeeds when service stubbed" do
    file = Rack::Test::UploadedFile.new(
      StringIO.new("xlsx content"),
      "application/vnd.openxmlformats-officedocument.spreadsheet.sheet",
      true,
      original_filename: "test.xlsx"
    )
    original_call = ExcelUploaderService.method(:call)
    ExcelUploaderService.define_singleton_method(:call) { |*_| true }
    begin
      post source_files_url, params: { bank: "visa", file: file }
      assert_redirected_to upload_path
      assert_equal "Procesamiento de VISA iniciado correctamente.", flash[:notice]
    ensure
      ExcelUploaderService.define_singleton_method(:call) { |*args| original_call.call(*args) }
    end
  end
end
