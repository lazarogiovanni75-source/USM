class CreateWaitlistEmails < ActiveRecord::Migration[7.2]
  def change
    create_table :waitlist_emails do |t|
      t.string :email, null: false
      t.string :status, default: 'pending' # pending, invited, converted
      t.timestamps
    end

    add_index :waitlist_emails, :email, unique: true
  end
end
