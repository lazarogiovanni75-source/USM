class CreatePromptTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :prompt_templates, force: true do |t|
      t.belongs_to :user, null: false
      t.string :name
      t.string :category
      t.text :prompt
      t.text :description
      t.json :variables
      t.boolean :is_public, default: false

      t.timestamps
    end
    add_index :prompt_templates, :user_id, if_not_exists: true
    add_index :prompt_templates, :is_public, if_not_exists: true
  end
end
