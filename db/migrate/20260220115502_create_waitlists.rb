class CreateWaitlists < ActiveRecord::Migration[7.2]
  def change
    create_table :waitlists do |t|
      t.string :email
      t.boolean :status, default: true

      t.timestamps
    end
    add_index :waitlists, :email, unique: true
  end
end
