# frozen_string_literal: true

require "test_helper"

module EventStore
  class ArchiverServiceTest < ActiveSupport::TestCase
    setup do
      @old_event_id = SecureRandom.uuid
      @recent_event_id = SecureRandom.uuid

      StoredEvent.append!(
        id: @old_event_id,
        event_type: "transaction.approved",
        event_version: 1,
        occurred_at: 3.years.ago,
        aggregate_type: "Transaction",
        aggregate_id: "old-1",
        stream_id: "Transaction:old-1",
        body: { "monto" => 100 }
      )

      StoredEvent.append!(
        id: @recent_event_id,
        event_type: "transaction.approved",
        event_version: 1,
        occurred_at: 1.month.ago,
        aggregate_type: "Transaction",
        aggregate_id: "recent-1",
        stream_id: "Transaction:recent-1",
        body: { "monto" => 200 }
      )
    end

    test "archive moves old events to archive table" do
      assert_equal 2, StoredEvent.count
      assert_equal 0, ArchivedEvent.count

      result = ArchiverService.archive(older_than: 2.years.ago)

      assert_equal 1, result[:archived_count]
      assert_equal false, result[:dry_run]
      assert_equal 1, StoredEvent.count
      assert_equal 1, ArchivedEvent.count

      assert_nil StoredEvent.find_by(id: @old_event_id)
      assert StoredEvent.find_by(id: @recent_event_id)
      assert ArchivedEvent.find_by(id: @old_event_id)
    end

    test "archive dry_run does not move events" do
      result = ArchiverService.archive(older_than: 2.years.ago, dry_run: true)

      assert_equal 1, result[:archived_count]
      assert_equal true, result[:dry_run]
      assert_equal 2, StoredEvent.count
      assert_equal 0, ArchivedEvent.count
    end

    test "archive respects batch_size" do
      5.times do |i|
        StoredEvent.append!(
          id: SecureRandom.uuid,
          event_type: "file.processed",
          event_version: 1,
          occurred_at: (3 + i).years.ago,
          aggregate_type: "SourceFile",
          aggregate_id: "batch-#{i}",
          stream_id: "SourceFile:batch-#{i}",
          body: {}
        )
      end

      result = ArchiverService.archive(older_than: 2.years.ago, batch_size: 2)

      assert_equal 6, result[:archived_count]
      assert_equal 6, ArchivedEvent.count
    end

    test "archive does nothing when no old events" do
      StoredEvent.where("occurred_at < ?", 2.years.ago).delete_all

      result = ArchiverService.archive(older_than: 2.years.ago)

      assert_equal 0, result[:archived_count]
    end
  end
end
