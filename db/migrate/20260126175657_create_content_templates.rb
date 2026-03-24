class CreateContentTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :content_templates, force: true do |t|
      t.belongs_to :user, null: false
      t.string :name
      t.string :category
      t.text :content
      t.json :variables
      t.string :platform
      t.boolean :is_active, default: true

      t.timestamps
    end
    add_index :content_templates, :user_id, if_not_exists: true
    add_index :content_templates, :is_active, if_not_exists: true
  end
end
