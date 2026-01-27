class CreateZapierWebhooks < ActiveRecord::Migration[7.2]
  def change
    create_table :zapier_webhooks, force: true do |t|
      t.belongs_to :user, null: false
      t.string :webhook_url
      t.string :event_type
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :zapier_webhooks, :user_id, if_not_exists: true
    add_index :zapier_webhooks, :is_active, if_not_exists: true
  end
end
