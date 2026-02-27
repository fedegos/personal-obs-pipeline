# frozen_string_literal: true

require "test_helper"

class EventStoreControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :users

  setup do
    sign_in users(:one)
    StoredEvent.append!(
      id: SecureRandom.uuid,
      event_type: "transaction.approved",
      event_version: 1,
      occurred_at: 1.hour.ago,
      aggregate_type: "Transaction",
      aggregate_id: "evt-1",
      stream_id: "Transaction:evt-1",
      body: { "monto" => 100 }
    )
    @event = StoredEvent.by_stream("Transaction:evt-1").first
  end

  test "index requires authentication" do
    sign_out :user
    get event_store_url
    assert_redirected_to new_user_session_url
  end

  test "index by stream_id returns events for that stream" do
    StoredEvent.append!(
      id: SecureRandom.uuid,
      event_type: "transaction.approved",
      event_version: 1,
      occurred_at: 2.hours.ago,
      aggregate_type: "Transaction",
      aggregate_id: "evt-2",
      stream_id: "Transaction:evt-2",
      body: {}
    )
    other = StoredEvent.by_stream("Transaction:evt-2").first

    get event_store_url, params: { stream_id: "Transaction:evt-1" }, as: :json
    assert_response :success

    data = response.parsed_body
    assert data.is_a?(Array)
    ids = data.map { |e| e["id"] }
    assert_includes ids, @event.id
    assert_not_includes ids, other.id
  end

  test "index by from and to filters by occurred_at" do
    from = 2.hours.ago.iso8601
    to = 30.minutes.ago.iso8601

    get event_store_url, params: { from: from, to: to }, as: :json
    assert_response :success

    data = response.parsed_body
    assert data.is_a?(Array)
    data.each do |e|
      assert e["occurred_at"] >= from
      assert e["occurred_at"] <= to
    end
  end

  test "index returns envelope fields in json (with upcasting to current version)" do
    get event_store_url, params: { stream_id: "Transaction:evt-1" }, as: :json
    assert_response :success

    data = response.parsed_body
    assert data.first["id"].present?
    assert_equal "transaction.approved", data.first["event_type"]
    # Stored as v1; API expone versión actual (v2) tras upcast
    assert_equal 2, data.first["event_version"]
    assert_equal "Transaction", data.first["aggregate_type"]
    assert_equal "evt-1", data.first["aggregate_id"]
    assert_equal "Transaction:evt-1", data.first["stream_id"]
    assert_equal 100, data.first["body"]["monto"]
    assert_equal [], data.first["body"]["etiquetas"], "v2 añade etiquetas por upcast"
  end

  test "index respects limit param" do
    5.times do |i|
      StoredEvent.append!(
        id: SecureRandom.uuid,
        event_type: "transaction.approved",
        event_version: 1,
        occurred_at: (i + 1).hours.ago,
        aggregate_type: "Transaction",
        aggregate_id: "evt-#{i}",
        stream_id: "Transaction:evt-1",
        body: {}
      )
    end

    get event_store_url, params: { stream_id: "Transaction:evt-1", limit: 2 }, as: :json
    assert_response :success
    assert_equal 2, response.parsed_body.size
  end

  test "index clamps limit to 1000" do
    get event_store_url, params: { limit: 9999 }, as: :json
    assert_response :success
    # Solo comprobamos que no rompe; el controlador usa clamp(1, 1000)
  end
end
