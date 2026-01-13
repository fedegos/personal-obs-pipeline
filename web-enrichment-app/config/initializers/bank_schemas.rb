# config/initializers/bank_schemas.rb
BANK_SCHEMAS = {
  'amex' => [
    { key: 'credit_card', label: 'Número de Tarjeta', type: 'number', required: true}
  ],
  'visa' => [

  ],
  'bbva' => [
    { key: 'credit_card', label: 'Número de Tarjeta', type: 'number', required: true},
    { key: 'card_number', label: 'Red', type: 'string', required: true}
  ]
}.with_indifferent_access.freeze
