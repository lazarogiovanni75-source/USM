class AddBufferFieldsToSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_accounts, :buffer_profile_id, :string
    add_column :social_accounts, :buffer_access_token, :string

  end
end
