class SentimentService
  def self.analyze(text)
    return 'Deseo' if text.blank?

    # Lógica simple basada en categorías clave para 2026
    case CategorizerService.guess(text)
    when 'Supermercado', 'Hogar', 'Salud', 'Transporte'
      'Necesario'
    when 'Suscripciones', 'Restaurantes'
      'Deseo'
    else
      'Varios'
    end
  end
end
