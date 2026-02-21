class CategorizerService
  def self.guess(text)
    return { category: "Varios", sub_category: nil } if text.blank?

    # Usamos cache key versionado por máximo updated_at: cuando cambia una regla,
    # la versión cambia y cargamos frescas. Evita caché obsoleto entre procesos.
    version = CategoryRule.maximum(:updated_at)&.to_f || 0
    cache_key = "categorizer/rules/#{version}"

    rules = Rails.cache.fetch(cache_key) do
      CategoryRule.all.includes(:parent).to_a
    end

    # CORRECCIÓN: Usamos un signo menos (-) para prioridad
    # o invertimos el resultado al final.
    # Prioridad: mayor número primero.
    # Profundidad: r.parent_id ? 0 : 1 (esto está bien, prioriza hijas sobre padres)
    match = rules.sort_by { |r| [ -(r.priority || 0), r.parent_id ? 0 : 1 ] }
                  .find { |r| text.match?(Regexp.new(r.pattern, Regexp::IGNORECASE)) }

    if match
      category = match.parent_id ? match.parent.name : match.name
      sub_category = match.parent_id ? match.name : nil
      # Sentimiento: de la regla que matcheó o de la raíz (parent); si no hay, nil (fallback en SentimentService)
      sentimiento = match.sentimiento.presence || match.parent&.sentimiento
      if match.parent_id
        { category: match.parent.name, sub_category: match.name, sentimiento: sentimiento }
      else
        { category: match.name, sub_category: nil, sentimiento: sentimiento }
      end
    else
      { category: "Varios", sub_category: nil, sentimiento: nil }
    end
  end

  def self.clear_cache
    # No-op: el cache key incluye maximum(:updated_at), así que al cambiar una regla
    # la siguiente guess() usará una clave distinta y cargará frescas. Se mantiene
    # por compatibilidad (CategoryRule.after_commit lo llama).
  end
end
