require "test_helper"
require "ostruct"

class FileResultsConsumerTest < ActiveSupport::TestCase
  fixtures :source_files

  setup do
    @source_file = source_files(:one)
    @source_file.update!(status: "pending", processed_at: nil, error_message: nil)
  end

  test "consume updates SourceFile to processed when status completed" do
    fake_message = OpenStruct.new(payload: { "source_file_id" => @source_file.id, "status" => "completed" })
    consumer = FileResultsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }
    consumer.consume

    @source_file.reload
    assert_equal "processed", @source_file.status
    assert_not_nil @source_file.processed_at
  end

  test "consume updates SourceFile to failed when status not completed" do
    fake_message = OpenStruct.new(payload: { "source_file_id" => @source_file.id, "status" => "failed", "error" => "Algo falló" })
    consumer = FileResultsConsumer.allocate
    consumer.define_singleton_method(:messages) { [ fake_message ] }
    consumer.consume

    @source_file.reload
    assert_equal "failed", @source_file.status
    assert_equal "Algo falló", @source_file.error_message
  end
end
