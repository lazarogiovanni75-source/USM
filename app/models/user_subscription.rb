class UserSubscription < ApplicationRecord
  belongs_to :user
  belongs_to :subscription_plan
  has_one :payment, as: :payable, dependent: :destroy

  validates :subscription_plan, presence: true
  validates :user, presence: true

  enum :status, { pending: 'pending', active: 'active', canceled: 'canceled', expired: 'expired' }, default: :pending

  # Credit constants per plan type
  PLAN_CREDITS = {
    'starter' => 180,
    'entrepreneur' => 360,
    'pro' => 600
  }.freeze

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

  # Credit management methods

  # Returns the credit amount for the current plan
  def plan_credits
    PLAN_CREDITS[subscription_plan.name.downcase] || 180
  end

  # Deductions credits if sufficient balance exists
  # @param amount [Integer] Number of credits to deduct
  # @return [Boolean] true if deduction successful
  # @raise [StandardError] if insufficient credits or save fails
  def deduct_credits!(amount)
    unless credits_remaining >= amount
      raise StandardError, "Insufficient credits. Have #{credits_remaining}, need #{amount}"
    end

    self.credits_remaining -= amount
    save!
    Rails.logger.info "[Credits] Deducted #{amount} credits. User #{user_id} now has #{credits_remaining} remaining."
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Credits] Failed to deduct #{amount} credits for user #{user_id}: #{e.message}"
    raise StandardError, "Failed to save credit deduction: #{e.message}"
  end

  # Resets credits to full plan amount and updates reset timestamp
  # Called on subscription renewal or initial activation
  def reset_credits!
    self.credits_remaining = plan_credits
    self.credits_reset_at = Time.current
    save!
  end

  # Check if user has enough credits for a specific action
  # @param amount [Integer] Number of credits required
  # @return [Boolean] true if user has sufficient credits
  def has_credits?(amount)
    credits_remaining >= amount
  end

  # Returns a hash with current credit status
  def credit_status
    {
      remaining: credits_remaining,
      total: plan_credits,
      reset_at: credits_reset_at
    }
  end
end