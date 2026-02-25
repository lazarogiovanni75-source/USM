class PromoCode < ApplicationRecord
  validates :code, presence: true, uniqueness: true
  validates :discount_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :discount_amount, numericality: { greater_than_or_equal_to: 0 }

  # Check if promo code is valid
  def valid_for_use?
    is_active? && (expires_at.nil? || expires_at > Time.current) && (max_uses.nil? || use_count < max_uses)
  end

  # Calculate discounted price
  def apply_discount(original_price)
    return original_price unless valid_for_use?

    if discount_percent > 0
      # Calculate percentage discount
      discounted = original_price * (1 - discount_percent / 100.0)
    elsif discount_amount > 0
      # Calculate fixed amount discount
      discounted = [original_price - discount_amount, 0].max
    else
      original_price
    end

    discounted.round(2)
  end

  # Increment usage count
  def use!
    increment!(:use_count) if valid_for_use?
  end
end
