# frozen_string_literal: true

module Admin
  # Visor de eventos del Event Repository con filtros, snapshots y proyecciones.
  # Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
  class EventsController < ApplicationController
    before_action :authenticate_user!

    ITEMS_PER_PAGE = 50

    def index
      scope = build_filtered_scope
      @pagy, @events = pagy(scope.order(occurred_at: :desc, sequence_number: :desc), limit: ITEMS_PER_PAGE)
      @stats = quick_stats
      @event_types = StoredEvent.distinct.pluck(:event_type).sort
      @aggregate_types = StoredEvent.distinct.pluck(:aggregate_type).sort
    end

    def show
      @event = find_event
      @read = EventStore::ReaderWithUpcast.read_event(@event)
      @stream_events = StoredEvent.by_stream(@event.stream_id).limit(20)
      @prev_event = StoredEvent.where(stream_id: @event.stream_id)
                               .where("sequence_number < ?", @event.sequence_number)
                               .order(sequence_number: :desc).first
      @next_event = StoredEvent.where(stream_id: @event.stream_id)
                               .where("sequence_number > ?", @event.sequence_number)
                               .order(sequence_number: :asc).first
    end

    def snapshot
      @event = find_event
      @snapshot = EventStore::AggregateProjector.project(
        @event.stream_id,
        until_sequence_number: @event.sequence_number
      )

      respond_to do |format|
        format.html
        format.json { render json: @snapshot }
        format.turbo_stream
      end
    end

    def stream
      @stream_id = params[:stream_id]
      return redirect_to admin_events_path, alert: "stream_id requerido" if @stream_id.blank?

      @events = StoredEvent.by_stream(@stream_id)
      @current_snapshot = EventStore::AggregateProjector.project(@stream_id)
    end

    def stats
      @total_count = StoredEvent.count
      @archived_count = ArchivedEvent.count
      @by_event_type = StoredEvent.group(:event_type).count.sort_by { |_, v| -v }
      @by_aggregate_type = StoredEvent.group(:aggregate_type).count.sort_by { |_, v| -v }
      @oldest = StoredEvent.order(:occurred_at).first
      @newest = StoredEvent.order(occurred_at: :desc).first
      @by_month = StoredEvent.group("DATE_TRUNC('month', occurred_at)").count.sort_by { |k, _| k }.last(12)
    end

    private

    def find_event
      StoredEvent.find_by!(sequence_number: params[:id])
    end

    def build_filtered_scope
      scope = StoredEvent.all

      scope = scope.where(event_type: params[:event_type]) if params[:event_type].present?
      scope = scope.where(aggregate_type: params[:aggregate_type]) if params[:aggregate_type].present?
      scope = scope.where(stream_id: params[:stream_id]) if params[:stream_id].present?
      scope = scope.where("occurred_at >= ?", params[:from]) if params[:from].present?
      scope = scope.where("occurred_at <= ?", params[:to]) if params[:to].present?

      if params[:q].present?
        escaped = params[:q].to_s.gsub(/[%_\\]/) { |c| "\\#{c}" }
        scope = scope.where("body::text ILIKE ?", "%#{escaped}%")
      end

      scope
    end

    def quick_stats
      {
        total: StoredEvent.count,
        today: StoredEvent.where("occurred_at >= ?", Time.current.beginning_of_day).count,
        this_week: StoredEvent.where("occurred_at >= ?", 1.week.ago).count
      }
    end
  end
end
