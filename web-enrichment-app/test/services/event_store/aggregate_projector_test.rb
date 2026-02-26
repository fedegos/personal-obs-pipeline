# frozen_string_literal: true

require "test_helper"

module EventStore
  class AggregateProjectorTest < ActiveSupport::TestCase
    setup do
      @stream_id = "Transaction:proj-test-1"

      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.created",
        event_version: 1,
        occurred_at: 3.hours.ago,
        aggregate_type: "Transaction",
        aggregate_id: "proj-test-1",
        stream_id: @stream_id,
        body: { "event_id" => "proj-test-1", "monto" => 100, "categoria" => "Inicial" }
      )
      @created_event = StoredEvent.by_stream(@stream_id).first

      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.updated",
        event_version: 1,
        occurred_at: 2.hours.ago,
        aggregate_type: "Transaction",
        aggregate_id: "proj-test-1",
        stream_id: @stream_id,
        body: { "categoria" => "Supermercado", "sentimiento" => "Necesario" }
      )
      @updated_event = StoredEvent.by_stream(@stream_id).second

      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.updated",
        event_version: 1,
        occurred_at: 1.hour.ago,
        aggregate_type: "Transaction",
        aggregate_id: "proj-test-1",
        stream_id: @stream_id,
        body: { "aprobado" => true }
      )
      @approved_event = StoredEvent.by_stream(@stream_id).third
    end

    test "project returns full state when no until_sequence_number" do
      state = AggregateProjector.project(@stream_id)

      assert_equal "proj-test-1", state["event_id"]
      assert_equal 100, state["monto"]
      assert_equal "Supermercado", state["categoria"]
      assert_equal "Necesario", state["sentimiento"]
      assert_equal true, state["aprobado"]
    end

    test "project until specific sequence_number returns partial state" do
      state = AggregateProjector.project(@stream_id, until_sequence_number: @updated_event.sequence_number)

      assert_equal "proj-test-1", state["event_id"]
      assert_equal 100, state["monto"]
      assert_equal "Supermercado", state["categoria"]
      assert_equal "Necesario", state["sentimiento"]
      assert_nil state["aprobado"]
    end

    test "project until first event returns only created state" do
      state = AggregateProjector.project(@stream_id, until_sequence_number: @created_event.sequence_number)

      assert_equal "proj-test-1", state["event_id"]
      assert_equal 100, state["monto"]
      assert_equal "Inicial", state["categoria"]
      assert_nil state["sentimiento"]
      assert_nil state["aprobado"]
    end

    test "project marks deleted when destroyed event present" do
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.destroyed",
        event_version: 1,
        occurred_at: Time.current,
        aggregate_type: "Transaction",
        aggregate_id: "proj-test-1",
        stream_id: @stream_id,
        body: {}
      )

      state = AggregateProjector.project(@stream_id)

      assert_equal true, state["_deleted"]
      assert_equal "proj-test-1", state["event_id"]
    end

    test "project returns empty hash for unknown stream" do
      state = AggregateProjector.project("Unknown:nonexistent")
      assert_equal({}, state)
    end

    test "project handles transaction.approved event" do
      stream = "Transaction:approved-test"
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.approved",
        event_version: 1,
        occurred_at: 1.hour.ago,
        aggregate_type: "Transaction",
        aggregate_id: "approved-test",
        stream_id: stream,
        body: { "event_id" => "approved-test", "monto" => 500, "categoria" => "Ocio" }
      )

      state = AggregateProjector.project(stream)

      assert_equal "approved-test", state["event_id"]
      assert_equal 500, state["monto"]
      assert_equal "Ocio", state["categoria"]
    end
  end
end
