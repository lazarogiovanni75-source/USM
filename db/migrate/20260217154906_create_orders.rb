class CreateOrders < ActiveRecord::Migration[7.2]
  def change
    create_table :orders do |t|
      t.references :user
      t.decimal :total, default: 0
      t.string :status, default: "pending"


      t.timestamps
    end
  end
end
