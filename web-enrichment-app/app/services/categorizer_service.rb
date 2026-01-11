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

  def self.guess_sub_category(text)
    return nil if text.blank?
    
    # Lógica simple: si el texto contiene una marca específica
    if text.match?(/NETFLIX/i) then 'Netflix'
    elsif text.match?(/SPOTIFY/i) then 'Spotify'
    elsif text.match?(/UBER/i) then 'Uber'
    elsif text.match?(/COTO/i) then 'Coto'
    else nil
    end
  end


end

