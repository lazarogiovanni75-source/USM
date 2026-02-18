class Order < ApplicationRecord
  belongs_to :user
  has_one :payment, as: :payable, dependent: :destroy
  
  validates :total, presence: true, numericality: { greater_than: 0 }
  
  # Payment interface methods - REQUIRED for Stripe integration
  def customer_name
    user.name
  end
  
  def customer_email
    user.email
  end
  
  def payment_description
    "Order ##{id}"
  end
  
  def stripe_mode
    'payment' # 'payment' for one-time, 'subscription' for recurring
  end
  
  def stripe_line_items
    [{
      price_data: {
        currency: 'usd',
        product_data: { name: payment_description },
        unit_amount: (total * 100).to_i # Convert dollars to cents
      },
      quantity: 1
    }]
  end
end
