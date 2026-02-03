# config/initializers/bank_schemas.rb
BANK_SCHEMAS = {
  "amex" => [
    { key: "credit_card", label: "Número de Tarjeta", type: "number", required: true },
    { key: "spreadsheet_id", label: "Google Sheet ID", type: "text", default: "AMEX" },
    { key: "sheet", label: "Hoja ", type: "text", default: "32003" }
  ],
  "visa" => [],
  "bbva" => [
    { key: "card_number", label: "Número de Tarjeta", type: "number", required: true },
    { key: "card_network", label: "Red", type: "string", required: true }
  ],
  "bbva_pdf_visa" => [
    { key: "card_number", label: "Número de Tarjeta (ej. XXXX XXXX XXXX 3689)", type: "text", required: true }
  ],
  "bapro_pdf_visa" => [
    { key: "card_number", label: "Número de Tarjeta (ej. XXXX XXXX XXXX 3689)", type: "text", required: true }
  ],
  "amex_pdf" => [
    { key: "card_number", label: "Número de Tarjeta (ej. XXXX XXXX 32003)", type: "text", required: true },
    { key: "year", label: "Año del resumen (ej. 2025)", type: "number", required: false }
  ]
}.with_indifferent_access.freeze

NO_FILE_BANKS = [ "amex" ].freeze
