# frozen_string_literal: true

require "test_helper"

module EventStore
  module Upcasters
    class TransactionApprovedUpcasterTest < ActiveSupport::TestCase
      setup do
        @upcaster = TransactionApprovedUpcaster.new
      end

      test "upcast from v1 to v2 adds etiquetas array when missing" do
        body_v1 = { "event_id" => "e1", "monto" => 100, "categoria" => "X" }
        result = @upcaster.upcast(body_v1.deep_dup, 1, 2)
        assert_equal [], result["etiquetas"]
        assert_equal "e1", result["event_id"]
        assert_equal 100, result["monto"]
      end

      test "upcast from v1 to v2 does not overwrite existing etiquetas" do
        body = { "event_id" => "e1", "etiquetas" => [ "urgente" ] }
        result = @upcaster.upcast(body.deep_dup, 1, 2)
        assert_equal [ "urgente" ], result["etiquetas"]
      end

      test "upcast returns same body when from_version >= to_version" do
        body = { "event_id" => "e1" }
        result = @upcaster.upcast(body.deep_dup, 2, 2)
        assert_equal body, result
        result = @upcaster.upcast(body.deep_dup, 2, 1)
        assert_equal body, result
      end

      test "upcast does not mutate original body" do
        body = { "event_id" => "e1" }
        orig = body.deep_dup
        @upcaster.upcast(body, 1, 2)
        assert_not body.key?("etiquetas"), "original should not be modified"
        assert_equal orig, body
      end
    end
  end
end
