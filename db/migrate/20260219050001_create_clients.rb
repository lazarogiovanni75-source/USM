class CreateClients < ActiveRecord::Migration[7.2]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.string :contact_name
      t.string :email
      t.string :phone
      t.text :address
      t.string :status, default: 'active', null: false
      t.string :plan, default: 'basic'
      t.decimal :monthly_budget, precision: 10, scale: 2
      t.text :notes
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end

    add_index :clients, :status
  end
end
