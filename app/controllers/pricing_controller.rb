class PricingController < ApplicationController
  def index
    @plans = SubscriptionPlan.all.order(:price_cents)
    @current_subscription = current_user&.user_subscriptions&.active&.first if user_signed_in?
  end
end
