class AddPostformeFieldsToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :postforme_post_id, :string
    add_column :draft_contents, :posted_at, :datetime
    add_column :draft_contents, :error_message, :text
    add_index :draft_contents, :postforme_post_id unless index_exists?(:draft_contents, :postforme_post_id)
  end
end
