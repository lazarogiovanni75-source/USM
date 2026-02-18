class SubscriptionsController < ApplicationController
  before_action :authenticate_user!

  def create
    plan = SubscriptionPlan.find(params[:plan_id])

    # Create pending subscription
    @subscription = current_user.user_subscriptions.create!(
      subscription_plan: plan,
      status: 'pending',
      started_at: Time.current,
      expires_at: 1.month.from_now
    )

    # Create payment record
    @payment = @subscription.create_payment!(
      amount: plan.price_dollars,
      user: current_user
    )

    # Redirect to Stripe checkout
    redirect_to pay_payment_path(@payment), data: { turbo_method: :post }
  end
end
