class CreateWaitlistEmails < ActiveRecord::Migration[7.0]
  def change
    create_table :waitlist_emails do |t|
      t.string :email, null: false
      t.string :commit
      t.timestamps
    end
    add_index :waitlist_emails, :email, unique: true
  end
end
