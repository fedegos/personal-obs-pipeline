# frozen_string_literal: true

require "test_helper"
require "ostruct"

class EventStoreConsumerTest < ActiveSupport::TestCase
  def build_consumer(topic_name, messages_payloads)
    topic = OpenStruct.new(name: topic_name)
    kafka_timestamp = Time.current
    messages = messages_payloads.map { |p| OpenStruct.new(payload: p.is_a?(String) ? p : p.to_json, timestamp: kafka_timestamp) }
    consumer = EventStoreConsumer.allocate
    consumer.define_singleton_method(:topic) { topic }
    consumer.define_singleton_method(:messages) { messages }
    consumer
  end

  test "consume domain_events persists envelope and body" do
    payload = {
      "event_type" => "transaction.updated",
      "entity_type" => "Transaction",
      "entity_id" => "evt-abc",
      "action" => "updated",
      "payload" => { "categoria" => "Hogar", "sentimiento" => "Necesario" },
      "timestamp" => 1.hour.ago.iso8601
    }
    consumer = build_consumer("domain_events", [ payload ])
    assert_difference "StoredEvent.count", 1 do
      consumer.consume
    end

    e = StoredEvent.order(sequence_number: :desc).first
    assert_equal "transaction.updated", e.event_type
    assert_equal 1, e.event_version
    assert_equal "Transaction", e.aggregate_type
    assert_equal "evt-abc", e.aggregate_id
    assert_equal "Transaction:evt-abc", e.stream_id
    assert_equal "Hogar", e.body["categoria"]
    assert_equal "Necesario", e.body["sentimiento"]
  end

  test "consume domain_events skips message when required fields missing" do
    consumer = build_consumer("domain_events", [ { "event_type" => "x", "entity_id" => "1" } ]) # no entity_type
    assert_no_difference "StoredEvent.count" do
      consumer.consume
    end
  end

  test "consume transacciones_clean persists as transaction.approved" do
    payload = {
      "event_id" => "evt-clean-1",
      "fecha" => 2.hours.ago.iso8601,
      "monto" => 5000,
      "categoria" => "Supermercado",
      "sentimiento" => "Necesario"
    }
    consumer = build_consumer("transacciones_clean", [ payload ])
    assert_difference "StoredEvent.count", 1 do
      consumer.consume
    end

    e = StoredEvent.order(sequence_number: :desc).first
    assert_equal "transaction.approved", e.event_type
    assert_equal 1, e.event_version
    assert_equal "Transaction", e.aggregate_type
    assert_equal "evt-clean-1", e.aggregate_id
    assert_equal "Transaction:evt-clean-1", e.stream_id
    assert_equal 5000, e.body["monto"]
    assert_equal "Supermercado", e.body["categoria"]
  end

  test "consume transacciones_clean skips when event_id or fecha missing" do
    consumer = build_consumer("transacciones_clean", [ { "event_id" => "x" } ])
    assert_no_difference "StoredEvent.count" do
      consumer.consume
    end
  end

  test "consume file_results persists as file.processed" do
    payload = {
      "source_file_id" => 99,
      "status" => "completed",
      "transactions_count" => 10,
      "message" => "10 transacciones"
    }
    consumer = build_consumer("file_results", [ payload ])
    assert_difference "StoredEvent.count", 1 do
      consumer.consume
    end

    e = StoredEvent.order(sequence_number: :desc).first
    assert_equal "file.processed", e.event_type
    assert_equal 1, e.event_version
    assert_equal "SourceFile", e.aggregate_type
    assert_equal "99", e.aggregate_id
    assert_equal "SourceFile:99", e.stream_id
    assert_equal 10, e.body["transactions_count"]
  end

  test "consume file_results skips when source_file_id or status missing" do
    consumer = build_consumer("file_results", [ { "status" => "completed" } ])
    assert_no_difference "StoredEvent.count" do
      consumer.consume
    end
  end

  test "consume unknown topic does not persist" do
    consumer = build_consumer("unknown_topic", [ { "event_type" => "x", "entity_type" => "Y", "entity_id" => "1", "timestamp" => Time.current.iso8601 } ])
    assert_no_difference "StoredEvent.count" do
      consumer.consume
    end
  end

  test "consume stores schema name in metadata when event_type is registered" do
    payload = {
      "event_id" => "evt-schema",
      "fecha" => 1.hour.ago.iso8601,
      "monto" => 100,
      "categoria" => "X",
      "sentimiento" => "Necesario"
    }
    consumer = build_consumer("transacciones_clean", [ payload ])
    consumer.consume

    e = StoredEvent.order(sequence_number: :desc).first
    assert_equal "TransactionApprovedV1", e.metadata["schema"]
    assert_equal true, e.metadata["schema_deprecated"], "v1 deprecated al existir v2"
  end
end
