class SourceFile < ApplicationRecord
  include DomainEventPublishable

  # Esto envía el cambio vía WebSockets automáticamente
  after_update_commit -> { broadcast_replace_to "source_files_channel" }
end
