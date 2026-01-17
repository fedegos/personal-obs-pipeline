class Transaction < ApplicationRecord
  # Validaciones para asegurar integridad antes de enviar a InfluxDB
  validates :event_id, presence: true, uniqueness: true
  validates :monto, :fecha, :detalles, presence: true

  # Scopes útiles para tu controlador
  scope :pendientes, -> { where(aprobado: false) }
  scope :aprobadas, -> { where(aprobado: true) }

  after_update_commit -> { broadcast_remove_to "transactions_channel" }

  # Método para verificar si está lista para ser publicada en Kafka Clean
  def ready_to_publish?
    aprobado? && categoria.present? && sentimiento.present?
  end
end