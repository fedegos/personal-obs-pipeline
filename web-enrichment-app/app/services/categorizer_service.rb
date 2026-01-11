class CategorizerService
  # Diccionario de categorías y sus palabras clave
  RULES = {
    'Supermercado' => /COTO|CARREFOUR|JUMBO|DISCO|DIA|VITAL/i,
    'Suscripciones' => /NETFLIX|SPOTIFY|APPLE|GOOGLE|DISNEY|PRIME/i,
    'Transporte' => /UBER|CABIFY|DIDI|SUBE|SHELL|AXION|YPF/i,
    'Hogar' => /EDENOR|EDESUR|AYSA|METROGAS|TELECOM|FIBERTEL/i,
    'Restaurantes' => /PEDIDOSYA|RAPPI|MCDONALD|BURGER|CAFE|CERVEZA/i,
    'Salud' => /OSDE|SWISS MEDICAL|FARMACIA|GALENO/i
  }.freeze

  def self.guess(text)
    return 'Varios' if text.blank?

    # Buscamos la primera regla que coincida
    category = RULES.find { |_name, regex| text.match?(regex) }
    
    category ? category.first : 'Varios'
  end
end

