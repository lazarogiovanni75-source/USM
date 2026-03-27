class CampaignTemplate < ApplicationRecord
  has_many :campaigns, dependent: :nullify

  validates :name, presence: true
  validates :duration_days, presence: true, numericality: { greater_than: 0 }
  validates :structure, presence: true

  scope :active, -> { where(is_active: true) }
  scope :by_category, ->(category) { where(category: category) if category.present? }

  def days
    structure['days'] || []
  end

  def platforms
    structure['platforms'] || []
  end

  def theme
    structure['theme'] || 'General'
  end
end
