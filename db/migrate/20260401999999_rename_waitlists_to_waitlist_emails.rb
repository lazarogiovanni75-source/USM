class RenameWaitlistsToWaitlistEmails < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:waitlist_emails)
      if table_exists?(:waitlists)
        rename_table :waitlists, :waitlist_emails
      else
        create_table :waitlist_emails do |t|
          t.string :email, null: false
          t.string :status, default: 'pending'
          t.timestamps
        end
        add_index :waitlist_emails, :email, unique: true
      end
    end
  end
end
