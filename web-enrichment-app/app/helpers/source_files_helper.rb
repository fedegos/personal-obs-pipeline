# frozen_string_literal: true

module SourceFilesHelper
  # Mapa de keys a labels (extraído de BANK_SCHEMAS)
  PARAM_LABELS = BANK_SCHEMAS.values.flat_map { |fields| fields.map { |f| [f[:key].to_s, f[:label]] } }.to_h.freeze

  def format_extra_params(source_file)
    return [] if source_file.extra_params.blank?

    source_file.extra_params.map do |key, value|
      label = PARAM_LABELS[key.to_s] || key.to_s.humanize
      { label: label, value: value.to_s }
    end
  end
end
