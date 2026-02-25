class CreatePromoCodes < ActiveRecord::Migration[7.2]
  def change
    create_table :promo_codes do |t|
      t.string :code
      t.integer :discount_percent, default: 0
      t.integer :discount_amount, default: 0
      t.boolean :is_active, default: true
      t.datetime :expires_at
      t.integer :max_uses
      t.integer :use_count, default: 0
      t.string :+
      t.string :migration


      t.timestamps
    end
  end
end
