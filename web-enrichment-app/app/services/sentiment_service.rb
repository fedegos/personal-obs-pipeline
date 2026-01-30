class SentimentService
  # Usa el sentimiento de la regla de categoría cuando viene en el hash; si no, fallback.
  # Devuelve siempre una de las 5 claves de Transaction::SENTIMIENTOS.
  def self.analyze(text)
    return "Deseo" if text.blank?

    result = CategorizerService.guess(text)
    suggested = result[:sentimiento]
    return suggested if suggested.present? && Transaction::SENTIMIENTOS.key?(suggested)

    "Deseo"
  end
end
