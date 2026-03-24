class AddErrorMessageToVideos < ActiveRecord::Migration[7.2]
  def change
    add_column :videos, :error_message, :text

  end
end
