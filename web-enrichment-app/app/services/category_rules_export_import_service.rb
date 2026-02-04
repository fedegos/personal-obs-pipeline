# frozen_string_literal: true

class CategoryRulesExportImportService
  class << self
    # Exporta todas las reglas como JSON: raíces primero, luego hijos.
    # Cada ítem: name, pattern, priority, sentimiento (opcional), parent_name (nil para raíces).
    def export
      array = []
      CategoryRule.roots.order(:id).each do |root|
        array << rule_to_hash(root)
        root.children.order(:id).each do |child|
          array << rule_to_hash(child)
        end
      end
      array.to_json
    end

    # Importa desde JSON. Idempotente: crea si no existe, actualiza si existe (pisa por nombre+ nivel).
    # Unicidad: (name, parent_id). No se permiten categorías ni subcategorías con nombre duplicado al mismo nivel.
    # Orden esperado: raíces primero, luego hijos. parent_name que no exista => ArgumentError.
    def import(json_string)
      data = JSON.parse(json_string)
      return {} unless data.is_a?(Array)

      name_to_id = {} # para resolver parent_name -> id

      data.each do |h|
        name = h["name"]
        pattern = h["pattern"]
        priority = h["priority"]
        sentimiento = h["sentimiento"].presence
        parent_name = h["parent_name"].presence

        parent_id = if parent_name
          id = name_to_id[parent_name]
          raise ArgumentError, "parent_name '#{parent_name}' no existe (debe venir antes en el JSON)" unless id
          id
        end

        # Buscar por nombre + nivel (parent_id). Si existe, pisar; si no, crear.
        existing = CategoryRule.find_by(name: name, parent_id: parent_id)

        if existing
          changed = (existing.pattern != pattern) || (existing.priority != priority) || (existing.sentimiento != sentimiento)
          existing.update!(pattern: pattern, priority: priority, sentimiento: sentimiento) if changed
        else
          existing = CategoryRule.create!(name: name, pattern: pattern, priority: priority, sentimiento: sentimiento, parent_id: parent_id)
        end
        name_to_id[name] = existing.id
      end

      {}
    end

    private

    def rule_to_hash(rule)
      {
        "name"         => rule.name,
        "pattern"      => rule.pattern,
        "priority"     => rule.priority,
        "sentimiento"  => rule.sentimiento,
        "parent_name"  => rule.parent_id? ? rule.parent.name : nil
      }
    end
  end
end
