# frozen_string_literal: true

# Registra upcasters del Event Repository al arranque.
# Ver DOCS/EVENT-REPOSITORY-DESIGN.md (Fase 3).
Rails.application.config.to_prepare do
  EventStore::UpcasterRegistry.register(
    "transaction.approved",
    EventStore::Upcasters::TransactionApprovedUpcaster.new
  )
end
