require "test_helper"

class SourceFileTest < ActiveSupport::TestCase
  test "fixture is valid" do
    assert source_files(:one).valid?
  end

  test "can create with minimal attributes" do
    sf = SourceFile.new(bank: "visa", file_key: "raw/visa/123_test.xlsx", status: "pending")
    assert sf.valid?
    assert sf.save
  end

  test "can have extra_params as hash" do
    sf = SourceFile.create!(bank: "amex", file_key: "api/amex/1", status: "pending", extra_params: { "credit_card" => "123" })
    assert_equal({ "credit_card" => "123" }, sf.extra_params)
  end
end
