# frozen_string_literal: true

class AddPostformeFieldsToSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_accounts, :postforme_api_key, :string
    add_column :social_accounts, :postforme_profile_id, :string

    # Remove deprecated Buffer fields (optional - uncomment if you want to remove them)
    # remove_column :social_accounts, :buffer_access_token, :string
    # remove_column :social_accounts, :buffer_profile_id, :string
  end
end
