class CreateAutoResponseModels < ActiveRecord::Migration[7.2]
  def change
    create_table :auto_response_triggers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :trigger_type, null: false
      t.string :response_type, null: false
      t.string :status, default: 'active'
      t.text :conditions, array: true, default: []
      t.jsonb :config, default: {}
      t.timestamps
    end
    
    create_table :response_templates do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.text :body, null: false
      t.string :category, default: 'custom'
      t.boolean :active, default: true
      t.timestamps
    end
    
    create_table :auto_responses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :content, null: false, foreign_key: true
      t.references :auto_response_trigger, null: true, foreign_key: true
      t.references :response_template, null: true, foreign_key: true
      t.string :response_type, null: false
      t.string :status, default: 'generated'
      t.text :ai_generated_text
      t.datetime :sent_at
      t.jsonb :response_data, default: {}
      t.timestamps
    end
    
    create_table :trigger_executions do |t|
      t.references :auto_response_trigger, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'executed'
      t.jsonb :engagement_data, default: {}
      t.jsonb :response_data, default: {}
      t.timestamps
    end
    
    # Add indexes for performance
    add_index :auto_response_triggers, :status
    add_index :auto_response_triggers, :trigger_type
    add_index :auto_response_triggers, :response_type
    
    add_index :auto_responses, :status
    add_index :auto_responses, :response_type
    add_index :auto_responses, :created_at
    
    add_index :trigger_executions, :status
    add_index :trigger_executions, :created_at
    
    add_index :response_templates, :category
    add_index :response_templates, :active
  end
end