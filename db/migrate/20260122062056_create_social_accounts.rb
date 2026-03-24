class CreateSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    create_table :social_accounts do |t|
      t.references :user
      t.string :platform, default: "instagram"
      t.string :account_name, default: "Untitled"
      t.string :account_url
      t.string :access_token
      t.boolean :is_connected, default: false


      t.timestamps
    end
  end
end
