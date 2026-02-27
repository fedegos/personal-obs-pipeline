# config/initializers/bank_schemas.rb
# fecha_vencimiento: opcional para cargas parciales (Excel/CSV/PDF/Sheets). Ej. fecha de cierre del resumen.
COMMON_FILE_PARAMS = [
  { key: "fecha_vencimiento", label: "Fecha de vencimiento", type: "date", required: false, placeholder: "Ej. fecha de cierre del resumen" }
].freeze

BANK_SCHEMAS = {
  "amex" => [
    { key: "credit_card", label: "Número de Tarjeta", type: "number", required: true },
    { key: "spreadsheet_id", label: "Google Sheet ID", type: "text", default: "AMEX" },
    { key: "sheet", label: "Hoja ", type: "text", default: "32003" },
    { key: "fecha_vencimiento", label: "Fecha de vencimiento", type: "date", required: false, placeholder: "Ej. fecha de cierre del resumen" }
  ],
  "visa" => COMMON_FILE_PARAMS.dup,
  "bbva" => [
    { key: "card_number", label: "Número de Tarjeta", type: "number", required: true },
    { key: "card_network", label: "Red", type: "string", required: true }
  ] + COMMON_FILE_PARAMS,
  "bbva_pdf_visa" => [
    { key: "card_number", label: "Número de Tarjeta (ej. 9454)", type: "text", required: true }
  ] + COMMON_FILE_PARAMS,
  "bbva_pdf_mastercard" => [
    { key: "card_number", label: "Número de Tarjeta (ej. 3640)", type: "text", required: true }
  ] + COMMON_FILE_PARAMS,
  "bapro_pdf_visa" => [
    { key: "card_number", label: "Número de Tarjeta (ej. 3689)", type: "text", required: true }
  ] + COMMON_FILE_PARAMS,
  "bapro_pdf_mastercard" => [
    { key: "card_number", label: "Número de Tarjeta (ej. 7330)", type: "text", required: true }
  ] + COMMON_FILE_PARAMS,
  "amex_pdf" => [
    { key: "card_number", label: "Número de Tarjeta (ej. 32003)", type: "text", required: true },
    { key: "year", label: "Año del resumen (ej. 2025)", type: "number", required: false }
  ] + COMMON_FILE_PARAMS
}.with_indifferent_access.freeze

NO_FILE_BANKS = [ "amex" ].freeze
