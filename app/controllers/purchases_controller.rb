class PurchasesController < ApplicationController
  before_action :authenticate_user!
  
  def create
    # Example: Create an order and redirect to Stripe payment
    @order = Order.create!(
      user: current_user,
      total: params[:amount].to_f || 99.00,
      status: 'pending'
    )
    
    # Create payment record
    @payment = @order.create_payment!(
      amount: @order.total,
      user: current_user
    )
    
    # Redirect to Stripe checkout
    redirect_to pay_payment_path(@payment), data: { turbo_method: :post }
  end
end
