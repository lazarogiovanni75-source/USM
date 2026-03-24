class UpdateContentTemplatesSchema < ActiveRecord::Migration[7.2]
  def change
    # Add missing columns to existing content_templates table
    add_column :content_templates, :description, :text
    add_column :content_templates, :template_content, :text
    add_column :content_templates, :template_type, :text
    add_column :content_templates, :usage_count, :integer, default: 0
    add_column :content_templates, :is_featured, :boolean, default: false
    
    # Make user_id nullable (for public templates)
    change_column_null :content_templates, :user_id, true
    
    # Create separate variables table
    create_table :content_template_variables, force: true do |t|
      t.references :content_template, null: false, foreign_key: true
      t.string :variable_name, null: false
      t.text :variable_type, null: false
      t.text :default_value
      t.text :placeholder_text
      t.jsonb :validation_rules, default: '{}'
      t.timestamps
    end

    add_index :content_template_variables, :variable_name
    add_index :content_template_variables, :variable_type
  end
end