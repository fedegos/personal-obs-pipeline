# frozen_string_literal: true

require "test_helper"

module Admin
  class EventsControllerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    fixtures :users

    setup do
      sign_in users(:one)

      @stream_id = "Transaction:ctrl-test-1"
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.created",
        event_version: 1,
        occurred_at: 2.hours.ago,
        aggregate_type: "Transaction",
        aggregate_id: "ctrl-test-1",
        stream_id: @stream_id,
        body: { "event_id" => "ctrl-test-1", "monto" => 100 }
      )
      @event = StoredEvent.by_stream(@stream_id).first

      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.updated",
        event_version: 1,
        occurred_at: 1.hour.ago,
        aggregate_type: "Transaction",
        aggregate_id: "ctrl-test-1",
        stream_id: @stream_id,
        body: { "categoria" => "Supermercado" }
      )
      @updated_event = StoredEvent.by_stream(@stream_id).second
    end

    test "index requires authentication" do
      sign_out :user
      get admin_events_url
      assert_redirected_to new_user_session_url
    end

    test "index returns list of events" do
      get admin_events_url
      assert_response :success
      assert_select "table.events-table"
    end

    test "index filters by event_type" do
      get admin_events_url, params: { event_type: "transaction.created" }
      assert_response :success
    end

    test "index filters by aggregate_type" do
      get admin_events_url, params: { aggregate_type: "Transaction" }
      assert_response :success
    end

    test "index filters by stream_id" do
      get admin_events_url, params: { stream_id: @stream_id }
      assert_response :success
    end

    test "index filters by date range" do
      get admin_events_url, params: { from: 3.hours.ago.iso8601, to: Time.current.iso8601 }
      assert_response :success
    end

    test "index filters by search query in body" do
      get admin_events_url, params: { q: "ctrl-test-1" }
      assert_response :success
    end

    test "show displays event detail" do
      get admin_event_url(@event.sequence_number)
      assert_response :success
      assert_select ".event-metadata"
      assert_select ".event-body"
    end

    test "snapshot returns projected state" do
      get snapshot_admin_event_url(@updated_event.sequence_number)
      assert_response :success
      assert_select ".snapshot-panel"
    end

    test "snapshot returns json when requested" do
      get snapshot_admin_event_url(@updated_event.sequence_number), as: :json
      assert_response :success
      data = response.parsed_body
      assert_equal "ctrl-test-1", data["event_id"]
      assert_equal "Supermercado", data["categoria"]
    end

    test "stream shows events for a stream" do
      get stream_admin_events_url(stream_id: @stream_id)
      assert_response :success
      assert_select ".stream-current-state"
      assert_select ".stream-events-list"
    end

    test "stream redirects when stream_id missing" do
      get stream_admin_events_url
      assert_redirected_to admin_events_path
    end

    test "stats shows statistics" do
      get stats_admin_events_url
      assert_response :success
      assert_select ".stats-grid"
    end
  end
end
