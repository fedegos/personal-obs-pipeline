# frozen_string_literal: true

require "test_helper"

module EventStore
  class ReaderWithUpcastTest < ActiveSupport::TestCase
    setup do
      UpcasterRegistry.register("transaction.approved", Upcasters::TransactionApprovedUpcaster.new)
    end

    test "read_event returns body upcast to current version when stored version is older" do
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.approved",
        event_version: 1,
        occurred_at: 1.hour.ago,
        aggregate_type: "Transaction",
        aggregate_id: "evt-upcast",
        stream_id: "Transaction:evt-upcast",
        body: { "event_id" => "evt-upcast", "monto" => 200, "categoria" => "Y" }
      )
      ev = StoredEvent.by_stream("Transaction:evt-upcast").first
      current = EventSchemasRegistry.current_version("transaction.approved")
      assert current >= 2, "need v2 in schema for this test"

      result = ReaderWithUpcast.read_event(ev)

      assert_equal 200, result[:body]["monto"]
      assert_equal [], result[:body]["etiquetas"]
      assert_equal 2, result[:event_version], "exposed version is current after upcast"
    end

    test "read_event returns body and version unchanged when already current" do
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.approved",
        event_version: 2,
        occurred_at: 1.hour.ago,
        aggregate_type: "Transaction",
        aggregate_id: "evt-v2",
        stream_id: "Transaction:evt-v2",
        body: { "event_id" => "evt-v2", "monto" => 300, "etiquetas" => [ "a" ] }
      )
      ev = StoredEvent.by_stream("Transaction:evt-v2").first

      result = ReaderWithUpcast.read_event(ev)

      assert_equal 300, result[:body]["monto"]
      assert_equal [ "a" ], result[:body]["etiquetas"]
      assert_equal 2, result[:event_version]
    end
  end
end
