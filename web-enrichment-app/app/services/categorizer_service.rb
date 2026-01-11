class CategorizerService
  def self.guess(text)
    return { category: 'Varios', sub_category: nil } if text.blank?

    # Cargamos reglas (usamos ||= para caché simple)
    @rules ||= CategoryRule.all.includes(:parent).to_a

    # CORRECCIÓN: Usamos un signo menos (-) para prioridad 
    # o invertimos el resultado al final.
    # Prioridad: mayor número primero. 
    # Profundidad: r.parent_id ? 0 : 1 (esto está bien, prioriza hijas sobre padres)
    match = @rules.sort_by { |r| [-(r.priority || 0), r.parent_id ? 0 : 1] }
                  .find { |r| text.match?(Regexp.new(r.pattern, Regexp::IGNORECASE)) }

    if match
      if match.parent_id
        { category: match.parent.name, sub_category: match.name }
      else
        { category: match.name, sub_category: nil }
      end
    else
      { category: 'Varios', sub_category: nil }
    end
  end

  def self.clear_cache
    @rules = nil
  end
end
