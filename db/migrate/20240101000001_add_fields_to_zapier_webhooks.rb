class AddFieldsToZapierWebhooks < ActiveRecord::Migration[7.2]
  def change
    add_column :zapier_webhooks, :name, :string, null: false
    add_column :zapier_webhooks, :trigger_events, :text, array: true, default: []
    add_column :zapier_webhooks, :config, :jsonb, default: {}
    add_column :zapier_webhooks, :endpoint_id, :string
    add_column :zapier_webhooks, :status, :string, default: 'active'
    
    # Update existing records with default values
    ZapierWebhook.update_all(name: 'Untitled Webhook', status: 'active')
    
    # Add indexes for better performance
    add_index :zapier_webhooks, :endpoint_id, unique: true
    add_index :zapier_webhooks, :status
    add_index :zapier_webhooks, :trigger_events, using: 'gin'
  end
end