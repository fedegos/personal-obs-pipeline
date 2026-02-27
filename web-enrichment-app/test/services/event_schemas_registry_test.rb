# frozen_string_literal: true

require "test_helper"

class EventSchemasRegistryTest < ActiveSupport::TestCase
  test "load returns hash of event types and versions" do
    reg = EventSchemasRegistry.load
    assert reg.is_a?(Hash)
    assert reg.key?("transaction.approved")
    assert reg["transaction.approved"].is_a?(Hash)
    assert reg["transaction.approved"].key?("1")
  end

  test "schema_for returns schema name for event_type and version" do
    info = EventSchemasRegistry.schema_for("transaction.approved", 1)
    assert_equal "TransactionApprovedV1", info[:schema]
    assert_equal true, info[:deprecated], "v1 marcada deprecated al existir v2"
    info2 = EventSchemasRegistry.schema_for("transaction.approved", 2)
    assert_equal "TransactionApprovedV2", info2[:schema]
    assert_equal false, info2[:deprecated]
  end

  test "schema_for returns nil for unknown event_type" do
    info = EventSchemasRegistry.schema_for("unknown.event", 1)
    assert_nil info
  end

  test "schema_for returns nil for unknown version" do
    info = EventSchemasRegistry.schema_for("transaction.approved", 99)
    assert_nil info
  end

  test "current_version returns highest version for event_type" do
    v = EventSchemasRegistry.current_version("transaction.approved")
    assert v >= 1
  end

  test "current_version returns nil for unknown event_type" do
    assert_nil EventSchemasRegistry.current_version("unknown.event")
  end

  test "registered? returns true when event_type has versions" do
    assert EventSchemasRegistry.registered?("transaction.approved")
    assert EventSchemasRegistry.registered?("file.processed")
  end

  test "registered? returns false for unknown event_type" do
    assert_not EventSchemasRegistry.registered?("unknown.event")
  end
end
