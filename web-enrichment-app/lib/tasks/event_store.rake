# frozen_string_literal: true

# Tareas de mantenimiento del Event Repository.
# Ver: DOCS/EVENT-REPOSITORY-DESIGN.md y DOCS/OPERATIONS.md.
namespace :event_store do
  desc "Archivar eventos antiguos (> 2 años por defecto). Uso: rails event_store:archive [YEARS=2] [DRY_RUN=1] [BATCH=1000]"
  task archive: :environment do
    years = (ENV["YEARS"] || 2).to_i
    batch_size = (ENV["BATCH"] || 1000).to_i
    dry_run = ENV["DRY_RUN"].present?

    cutoff = years.years.ago
    puts "📦 Archivando eventos con occurred_at < #{cutoff.strftime('%Y-%m-%d')}"
    puts "   Batch size: #{batch_size}"
    puts "   Modo: #{dry_run ? 'DRY RUN (sin cambios)' : 'REAL (moverá eventos)'}"
    puts ""

    result = EventStore::ArchiverService.archive(
      older_than: cutoff,
      batch_size: batch_size,
      dry_run: dry_run
    )

    if dry_run
      puts "🔍 DRY RUN: se archivarían #{result[:archived_count]} eventos"
    else
      puts "✅ Archivados: #{result[:archived_count]} eventos movidos a event_store_archive"
    end
  end

  desc "Mostrar estadísticas del Event Store (conteos, fechas)"
  task stats: :environment do
    total = StoredEvent.count
    archived = ArchivedEvent.count
    oldest = StoredEvent.order(:occurred_at).first&.occurred_at
    newest = StoredEvent.order(occurred_at: :desc).first&.occurred_at

    puts "📊 Event Store Stats"
    puts "   Eventos activos: #{total}"
    puts "   Eventos archivados: #{archived}"
    puts "   Rango: #{oldest&.strftime('%Y-%m-%d') || 'N/A'} → #{newest&.strftime('%Y-%m-%d') || 'N/A'}"
  end
end
