class AddClientReferencesToCampaignsAndSocialAccounts < ActiveRecord::Migration[7.2]
  def change
    add_reference :campaigns, :client, foreign_key: true, index: true
    add_reference :social_accounts, :client, foreign_key: true, index: true
    
    # Add agency_role column for agency staff (role column already exists)
    unless column_exists?(:users, :agency_role)
      add_column :users, :agency_role, :string
    end
    
    # Add client management relationship
    add_reference :clients, :agency_user, foreign_key: { to_table: :users }, index: true
  end
end
