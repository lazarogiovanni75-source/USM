class AddPredictionUrlToVideos < ActiveRecord::Migration[7.2]
  def change
    add_column :videos, :prediction_url, :string

  end
end
