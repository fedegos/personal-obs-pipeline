# frozen_string_literal: true

# Evento archivado (tabla event_store_archive). Solo lectura.
# Ver DOCS/EVENT-REPOSITORY-DESIGN.md (Fase 4).
class ArchivedEvent < ApplicationRecord
  self.table_name = "event_store_archive"
  self.primary_key = "sequence_number"

  def readonly?
    true
  end
end
