class AddMediaUrlToContents < ActiveRecord::Migration[7.2]
  def change
    add_column :contents, :media_url, :string

  end
end
