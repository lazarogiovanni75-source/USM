class SubscriptionPlan < ApplicationRecord
  has_many :user_subscriptions, dependent: :destroy
  has_many :users, through: :user_subscriptions

  validates :name, presence: true
  validates :price_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :credits, presence: true, numericality: { greater_than_or_equal_to: 0 }

  def price_dollars
    price_cents / 100.0
  end

  def features_list
    features.present? ? features.split("\n") : []
  end
end
