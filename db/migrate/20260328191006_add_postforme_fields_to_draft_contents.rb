class AddPostformeFieldsToDraftContents < ActiveRecord::Migration[7.1]
  def change
    add_column :draft_contents, :platform,           :string unless column_exists?(:draft_contents, :platform)
    add_column :draft_contents, :postforme_post_id,  :string unless column_exists?(:draft_contents, :postforme_post_id)
  end
end
