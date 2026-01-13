# config/initializers/bank_schemas.rb
BANK_SCHEMAS = {
  'amex' => [
    { key: 'credit_card', label: 'Número de Tarjeta', type: 'number', required: true},
    { key: 'spreadsheet_id', label: 'Google Sheet ID', type: 'text', default: "AMEX"},
    { key: 'sheet', label: 'Hoja ', type: 'text', default: '32003' }
  ],
  'visa' => [

  ],
  'bbva' => [
    { key: 'credit_card', label: 'Número de Tarjeta', type: 'number', required: true},
    { key: 'card_number', label: 'Red', type: 'string', required: true}
  ]
}.with_indifferent_access.freeze

NO_FILE_BANKS = ['amex'].freeze
