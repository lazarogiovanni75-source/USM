class CreatePayments < ActiveRecord::Migration[7.2]
  def change
    create_table :payments do |t|
      t.references :payable, polymorphic: true, null: false
      t.references :user
      t.decimal :amount
      t.string :currency, default: "usd"
      t.string :status, default: "pending"
      t.string :stripe_payment_intent_id
      t.string :stripe_checkout_session_id
      t.string :payment_method
      t.jsonb :metadata

      t.timestamps
    end

    # Polymorphic index is automatically created by t.references
  end
end
