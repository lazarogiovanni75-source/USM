class PagesController < ApplicationController

  def features
    # Write your real logic here
  end


  def pricing
    @plans = SubscriptionPlan.all.order(:price_cents)
    @current_subscription = current_user&.user_subscriptions&.active&.first if user_signed_in?
  end


  def about
    # Write your real logic here
  end

  private
  # Write your private methods here
end
