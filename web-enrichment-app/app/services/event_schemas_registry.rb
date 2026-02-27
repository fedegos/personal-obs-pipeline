# frozen_string_literal: true

# Carga y consulta el registro de versiones de esquemas (config/event_schemas.yml).
# Ver DOCS/EVENT-REPOSITORY-DESIGN.md.
class EventSchemasRegistry
  class << self
    def load
      @loaded ||= begin
        path = Rails.root.join("config", "event_schemas.yml")
        return {} unless File.exist?(path)

        raw = YAML.load_file(path)
        return {} unless raw.is_a?(Hash)

        raw.transform_keys(&:to_s).transform_values do |versions|
          next {} unless versions.is_a?(Hash)

          versions.transform_keys(&:to_s).transform_values do |h|
            h.is_a?(Hash) ? h.transform_keys(&:to_s) : {}
          end
        end
      end
    end

    def schema_for(event_type, version)
      versions = load[event_type.to_s]
      return nil unless versions.is_a?(Hash)

      info = versions[version.to_s]
      return nil unless info.is_a?(Hash)

      {
        schema: (info["schema"] || info[:schema]).to_s,
        deprecated: info["deprecated"] == true || info[:deprecated] == true
      }
    end

    def current_version(event_type)
      versions = load[event_type.to_s]
      return nil unless versions

      versions.keys.map(&:to_i).max
    end

    def registered?(event_type)
      load.key?(event_type.to_s)
    end
  end
end
