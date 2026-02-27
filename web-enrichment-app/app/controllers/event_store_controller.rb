# frozen_string_literal: true

# API mínima para leer del Event Repository (solo lectura).
# Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
class EventStoreController < ApplicationController
  before_action :authenticate_user!

  def index
    if params[:stream_id].present?
      events = StoredEvent.by_stream(params[:stream_id]).limit(limit_param)
    else
      events = StoredEvent.by_occurred_at(from: params[:from], to: params[:to]).limit(limit_param)
    end

    render json: events.map { |e| event_to_json(e) }
  end

  private

  def event_to_json(event)
    read = EventStore::ReaderWithUpcast.read_event(event)
    {
      id: event.id,
      event_type: event.event_type,
      event_version: read[:event_version],
      occurred_at: event.occurred_at.iso8601,
      aggregate_type: event.aggregate_type,
      aggregate_id: event.aggregate_id,
      stream_id: event.stream_id,
      causation_id: event.causation_id,
      correlation_id: event.correlation_id,
      metadata: event.metadata,
      body: read[:body]
    }
  end

  def limit_param
    (params[:limit] || 100).to_i.clamp(1, 1000)
  end
end
