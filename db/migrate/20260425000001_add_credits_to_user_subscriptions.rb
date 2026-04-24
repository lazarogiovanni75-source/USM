class AddCreditsToUserSubscriptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_subscriptions, :credits_remaining, :integer, default: 0, null: false
    add_column :user_subscriptions, :credits_reset_at, :datetime
  end
end