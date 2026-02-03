require "test_helper"
require "ostruct"

class FileResultsConsumerTest < ActiveSupport::TestCase
  fixtures :source_files

  setup do
    @source_file = source_files(:one)
    @source_file.update!(status: "pending", processed_at: nil, error_message: nil, transactions_count: nil, processing_message: nil)
  end

  test "consume updates SourceFile to processed when status completed" do
    fake_message = OpenStruct.new(payload: {
      "source_file_id" => @source_file.id,
      "status" => "completed",
      "extractor" => "bbva_pdf_visa",
      "transactions_count" => 42,
      "message" => "42 transacciones procesadas"
    })
    consumer = FileResultsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }
    consumer.consume

    @source_file.reload
    assert_equal "processed", @source_file.status
    assert_not_nil @source_file.processed_at
    assert_equal 42, @source_file.transactions_count
    assert_equal "42 transacciones procesadas", @source_file.processing_message
  end

  test "consume updates SourceFile to failed when status not completed" do
    fake_message = OpenStruct.new(payload: {
      "source_file_id" => @source_file.id,
      "status" => "failed",
      "error" => "Algo falló",
      "extractor" => "amex_pdf",
      "transactions_count" => nil,
      "message" => nil
    })
    consumer = FileResultsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }
    consumer.consume

    @source_file.reload
    assert_equal "failed", @source_file.status
    assert_equal "Algo falló", @source_file.error_message
  end

  test "consume handles empty DataFrame result" do
    fake_message = OpenStruct.new(payload: {
      "source_file_id" => @source_file.id,
      "status" => "completed",
      "extractor" => "bbva_pdf_visa",
      "transactions_count" => 0,
      "message" => "Archivo vacío, 0 transacciones extraídas"
    })
    consumer = FileResultsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }
    consumer.consume

    @source_file.reload
    assert_equal "processed", @source_file.status
    assert_equal 0, @source_file.transactions_count
    assert_equal "Archivo vacío, 0 transacciones extraídas", @source_file.processing_message
  end
end
