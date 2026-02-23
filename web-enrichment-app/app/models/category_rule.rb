class CategoryRule < ApplicationRecord
  include DomainEventPublishable

  belongs_to :parent, class_name: "CategoryRule", optional: true
  has_many :children, class_name: "CategoryRule", foreign_key: "parent_id", dependent: :destroy

  validates :name, :pattern, presence: true
  validates :priority, numericality: { only_integer: true }
  validates :sentimiento, inclusion: { in: -> { Transaction::SENTIMIENTOS.keys }, message: "no es un sentimiento válido (Necesario, Deseo, Inversión, Ahorro, Hormiga)" }, allow_nil: true

  scope :roots, -> { where(parent_id: nil) }

  # IDs de la raíz y todos sus descendientes (para filtro por categoría)
  def self.subtree_ids(root_id)
    return [] if root_id.blank?
    ids = [ root_id.to_i ]
    frontier = ids.dup
    until frontier.empty?
      children = where(parent_id: frontier).pluck(:id)
      ids.concat(children)
      frontier = children
    end
    ids.uniq
  end

  # ID de la categoría raíz a la que pertenece esta regla
  def root_ancestor_id
    return id if parent_id.nil?
    parent.root_ancestor_id
  end

  # Limpia el caché del servicio cada vez que cambias una regla
  after_commit -> { CategorizerService.clear_cache }
end
