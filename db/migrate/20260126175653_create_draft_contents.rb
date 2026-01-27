class CreateDraftContents < ActiveRecord::Migration[7.2]
  def change
    create_table :draft_contents, force: true do |t|
      t.belongs_to :user, null: false
      t.string :title
      t.text :content
      t.string :content_type
      t.string :platform
      t.string :status, default: "draft"

      t.timestamps
    end
    add_index :draft_contents, :user_id, if_not_exists: true
    add_index :draft_contents, :status, if_not_exists: true
  end
end
