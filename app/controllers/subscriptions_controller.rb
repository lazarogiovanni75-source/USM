class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    plan = SubscriptionPlan.find(params[:plan_id])
    promo_code = params[:promo_code].presence
    
    # Calculate discounted price if promo code provided
    final_price = plan.price_dollars
    promo = nil
    
    if promo_code.present?
      promo = PromoCode.find_by(code: promo_code.upcase)
      if promo&.valid_for_use?
        final_price = promo.apply_discount(plan.price_dollars)
      end
    end

    # Create pending subscription
    @subscription = current_user.user_subscriptions.create!(
      subscription_plan: plan,
      status: 'pending',
      started_at: Time.current,
      expires_at: 1.month.from_now
    )

    # Create payment record with discounted amount
    @payment = @subscription.create_payment!(
      amount: final_price,
      user: current_user
    )

    # Store promo code on payment if used
    @payment.update!(metadata: { promo_code: promo.code }) if promo

    # Redirect to Stripe checkout
    redirect_to pay_payment_path(@payment), data: { turbo_method: :post }
  end
end
