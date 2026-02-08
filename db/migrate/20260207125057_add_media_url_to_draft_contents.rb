class AddMediaUrlToDraftContents < ActiveRecord::Migration[7.2]
  def change
    add_column :draft_contents, :media_url, :string

  end
end
