class CreateUserSubscriptions < ActiveRecord::Migration[7.2]
  def change
    create_table :user_subscriptions do |t|
      t.references :user
      t.references :subscription_plan
      t.string :status, default: "pending"
      t.datetime :started_at
      t.datetime :expires_at
      t.integer :credits_used, default: 0
      t.string :stripe_subscription_id


      t.timestamps
    end
  end
end
