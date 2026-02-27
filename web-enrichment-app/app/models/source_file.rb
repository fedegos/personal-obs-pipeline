class SourceFile < ApplicationRecord
  include DomainEventPublishable

  VALID_STATUSES = %w[uploaded processing processed failed].freeze
  VALID_BANKS = %w[visa bbva amex bapro_visa bapro_mc bbva_mc bbva_pdf bapro_pdf bapro_mc_pdf amex_pdf bbva_mc_pdf].freeze

  validates :file_key, presence: true
  validates :status, presence: true, inclusion: { in: VALID_STATUSES }
  validates :bank, presence: true, inclusion: { in: VALID_BANKS }

  # Esto envía el cambio vía WebSockets automáticamente
  after_update_commit -> { broadcast_replace_to "source_files_channel" }
end
