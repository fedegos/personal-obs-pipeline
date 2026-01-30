require "test_helper"

class ExcelUploaderServiceTest < ActiveSupport::TestCase
  test "call creates SourceFile and uses stubbed S3 and Karafka" do
    fake_s3 = Object.new
    def fake_s3.put_object(*_); end

    fake_producer = Object.new
    def fake_producer.produce_async(*_); end

    original_s3 = Object.const_get(:S3_CLIENT) rescue nil
    original_producer = Karafka.method(:producer)

    Object.send(:remove_const, :S3_CLIENT) if Object.const_defined?(:S3_CLIENT)
    Object.const_set(:S3_CLIENT, fake_s3)
    Karafka.define_singleton_method(:producer) { fake_producer }

    begin
      assert_difference("SourceFile.count", 1) do
        ExcelUploaderService.call(nil, "amex", { credit_card: "123", spreadsheet_id: "x", sheet: "y" })
      end

      sf = SourceFile.last
      assert_equal "amex", sf.bank
      assert_equal "pending", sf.status
      assert sf.file_key.start_with?("api/amex/")
      assert_equal({ "credit_card" => "123", "spreadsheet_id" => "x", "sheet" => "y" }, sf.extra_params)
    ensure
      Object.send(:remove_const, :S3_CLIENT) if Object.const_defined?(:S3_CLIENT)
      Object.const_set(:S3_CLIENT, original_s3) if original_s3
      Karafka.define_singleton_method(:producer) { |*args| original_producer.call(*args) }
    end
  end
end
