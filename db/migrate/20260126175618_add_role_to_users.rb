class AddRoleToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :role, :string
    add_column :users, :subscription_plan, :string
    add_column :users, :subscription_status, :string
    add_column :users, :subscription_expires_at, :datetime

  end
end
