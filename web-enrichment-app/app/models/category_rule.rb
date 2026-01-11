class CategoryRule < ApplicationRecord
  belongs_to :parent, class_name: 'CategoryRule', optional: true
  has_many :children, class_name: 'CategoryRule', foreign_key: 'parent_id', dependent: :destroy

  validates :name, :pattern, presence: true
  validates :priority, numericality: { only_integer: true }

  scope :roots, -> { where(parent_id: nil) }

  # Limpia el caché del servicio cada vez que cambias una regla
  after_commit -> { CategorizerService.clear_cache }
end
