class UserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :subscription_plan
  has_one :payment, as: :payable, dependent: :destroy

  validates :subscription_plan, presence: true
  validates :user, presence: true

  enum :status, { pending: 'pending', active: 'active', canceled: 'canceled', expired: 'expired' }, default: :pending

  # Payment interface methods - REQUIRED for Stripe integration
  def customer_name
    user.name
  end

  def customer_email
    user.email
  end

  def payment_description
    "#{subscription_plan.name} - Monthly Subscription"
  end

  def stripe_mode
    'subscription' # 'payment' for one-time, 'subscription' for recurring
  end

  def stripe_line_items
    [{
      price_data: {
        currency: 'usd',
        product_data: { name: subscription_plan.name },
        unit_amount: subscription_plan.price_cents,
        recurring: { interval: 'month' } # REQUIRED for subscription mode
      },
      quantity: 1
    }]
  end

  def active?
    status == 'active'
  end

  def expired?
    expires_at.present? && expires_at < Time.current
  end
end
