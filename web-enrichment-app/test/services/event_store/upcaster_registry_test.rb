# frozen_string_literal: true

require "test_helper"

module EventStore
  class UpcasterRegistryTest < ActiveSupport::TestCase
    test "register and fetch upcaster for event_type" do
      upcaster = Upcasters::TransactionApprovedUpcaster.new
      UpcasterRegistry.register("transaction.approved", upcaster)

      assert_equal upcaster, UpcasterRegistry.fetch("transaction.approved")
    end

    test "fetch returns nil for unregistered event_type" do
      assert_nil UpcasterRegistry.fetch("unknown.event")
    end

    test "apply_upcast returns body unchanged when version is current" do
      UpcasterRegistry.register("transaction.approved", Upcasters::TransactionApprovedUpcaster.new)
      body = { "event_id" => "e1", "etiquetas" => [] }
      result = UpcasterRegistry.apply_upcast("transaction.approved", body, 2, 2)
      assert_equal body, result
    end

    test "apply_upcast applies upcaster when from_version < to_version" do
      UpcasterRegistry.register("transaction.approved", Upcasters::TransactionApprovedUpcaster.new)
      body = { "event_id" => "e1", "monto" => 50 }
      result = UpcasterRegistry.apply_upcast("transaction.approved", body, 1, 2)
      assert_equal [], result["etiquetas"]
      assert_equal 50, result["monto"]
    end

    test "apply_upcast raises when event_type has no upcaster and versions differ" do
      body = { "x" => 1 }
      assert_raises(EventStore::UpcasterRegistry::NoUpcasterError) do
        UpcasterRegistry.apply_upcast("unknown.event", body, 1, 2)
      end
    end

    test "apply_upcast returns body when versions equal for unregistered type" do
      body = { "x" => 1 }
      result = UpcasterRegistry.apply_upcast("unknown.event", body, 1, 1)
      assert_equal body, result
    end
  end
end
