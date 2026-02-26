# frozen_string_literal: true

module EventStore
  # Mueve eventos antiguos de event_store a event_store_archive.
  # Los eventos archivados se eliminan de la tabla principal.
  # Ver DOCS/EVENT-REPOSITORY-DESIGN.md (Fase 4) y OPERATIONS.md.
  class ArchiverService
    DEFAULT_RETENTION_YEARS = 2
    DEFAULT_BATCH_SIZE = 1000

    class << self
      # @param older_than [ActiveSupport::Duration, Date, Time] eventos con occurred_at antes de esta fecha
      # @param batch_size [Integer] cuántos mover por batch (para evitar locks largos)
      # @param dry_run [Boolean] si true, solo reporta cuántos archivaría sin mover
      # @return [Hash] { archived_count:, dry_run: }
      def archive(older_than: DEFAULT_RETENTION_YEARS.years.ago, batch_size: DEFAULT_BATCH_SIZE, dry_run: false)
        cutoff = older_than.respond_to?(:to_time) ? older_than.to_time : older_than
        total_archived = 0

        loop do
          events = StoredEvent.where("occurred_at < ?", cutoff)
                              .order(:sequence_number)
                              .limit(batch_size)

          break if events.empty?

          if dry_run
            total_archived += events.count
            break if events.count < batch_size
            next
          end

          ActiveRecord::Base.transaction do
            rows = events.map do |e|
              {
                id: e[:id],
                event_type: e.event_type,
                event_version: e.event_version,
                occurred_at: e.occurred_at,
                aggregate_type: e.aggregate_type,
                aggregate_id: e.aggregate_id,
                stream_id: e.stream_id,
                causation_id: e.causation_id,
                correlation_id: e.correlation_id,
                metadata: e.metadata,
                body: e.body,
                created_at: e.created_at
              }
            end

            ArchivedEvent.insert_all(rows)
            StoredEvent.where(sequence_number: events.pluck(:sequence_number)).delete_all
            total_archived += rows.size
          end

          break if events.count < batch_size
        end

        { archived_count: total_archived, dry_run: dry_run }
      end
    end
  end
end
