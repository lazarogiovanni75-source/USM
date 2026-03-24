class CreateSubscriptionPlans < ActiveRecord::Migration[7.2]
  def change
    create_table :subscription_plans do |t|
      t.string :name
      t.integer :price_cents
      t.integer :credits
      t.text :description
      t.text :features
      t.boolean :is_popular


      t.timestamps
    end
  end
end
