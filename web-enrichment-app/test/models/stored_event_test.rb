# frozen_string_literal: true

require "test_helper"

class StoredEventTest < ActiveSupport::TestCase
  setup do
    @attrs = {
      id: SecureRandom.uuid,
      event_type: "transaction.approved",
      event_version: 1,
      occurred_at: 1.hour.ago,
      aggregate_type: "Transaction",
      aggregate_id: "evt-123",
      stream_id: "Transaction:evt-123",
      body: { "event_id" => "evt-123", "monto" => 100 }
    }
  end

  test "table_name is event_store" do
    assert_equal "event_store", StoredEvent.table_name
  end

  test "primary_key is sequence_number" do
    assert_equal "sequence_number", StoredEvent.primary_key
  end

  test "append! persists event with required attributes" do
    StoredEvent.append!(@attrs)
    e = StoredEvent.order(sequence_number: :desc).first
    assert e.persisted?
    assert_equal "transaction.approved", e.event_type
    assert_equal 1, e.event_version
    assert_equal "Transaction:evt-123", e.stream_id
    assert_equal "evt-123", e.aggregate_id
    assert e.sequence_number.present?
  end

  test "by_stream returns events for stream_id ordered by occurred_at" do
    StoredEvent.append!(@attrs.merge(occurred_at: 2.hours.ago))
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: 1.hour.ago))
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, stream_id: "Other:y", aggregate_id: "y"))
    other = StoredEvent.by_stream("Other:y").first

    rel = StoredEvent.by_stream("Transaction:evt-123")
    assert_equal 2, rel.count
    assert rel.pluck(:occurred_at).each_cons(2).all? { |a, b| a <= b }
    assert_not_includes rel.pluck(:id), other.id
  end

  test "by_occurred_at filters by from and to" do
    t1 = 3.hours.ago
    t2 = 2.hours.ago
    t3 = 1.hour.ago
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: t1))
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: t2))
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: t3))

    rel = StoredEvent.by_occurred_at(from: 3.5.hours.ago, to: 30.minutes.ago)
    assert rel.count >= 2, "expected at least 2 events in window (t2, t3)"
    assert rel.pluck(:occurred_at).min >= 3.5.hours.ago
    assert rel.pluck(:occurred_at).max <= 30.minutes.ago
  end

  test "by_occurred_at without from/to returns all ordered" do
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: 1.hour.ago))
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, occurred_at: 2.hours.ago))
    rel = StoredEvent.by_occurred_at(from: nil, to: nil)
    assert rel.count >= 2
    assert rel.pluck(:occurred_at).each_cons(2).all? { |a, b| a <= b }
  end

  test "by_event_type filters by event_type" do
    StoredEvent.append!(@attrs)
    StoredEvent.append!(@attrs.merge(id: SecureRandom.uuid, event_type: "file.processed", stream_id: "SourceFile:1", aggregate_type: "SourceFile", aggregate_id: "1"))
    rel = StoredEvent.by_event_type("transaction.approved")
    assert rel.where(event_type: "transaction.approved").count >= 1
    assert_equal 0, rel.where(event_type: "file.processed").count
  end

  test "record is readonly after load" do
    StoredEvent.append!(@attrs)
    e = StoredEvent.order(sequence_number: :desc).first
    assert e.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { e.update!(event_type: "other") }
  end
end
