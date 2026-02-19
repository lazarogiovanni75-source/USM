# frozen_string_literal: true

# Migration to add OAuth tokens and metadata to SocialAccount
class AddOauthTokensToSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_column :social_accounts, :oauth_access_token, :string
    add_column :social_accounts, :oauth_refresh_token, :string
    add_column :social_accounts, :oauth_expires_at, :datetime
    add_column :social_accounts, :oauth_metadata, :jsonb, default: {}
    add_column :social_accounts, :platform_user_id, :string
    add_column :social_accounts, :platform_username, :string
    
    # For encrypted fields, we'll use application-level encryption
    add_column :social_accounts, :encrypted_access_token, :string
    add_column :social_accounts, :encrypted_refresh_token, :string
  end
end
