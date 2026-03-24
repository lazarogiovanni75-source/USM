class CreateVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :videos do |t|
      t.references :user
      t.string :title
      t.text :description
      t.string :status
      t.string :video_type
      t.integer :duration


      t.timestamps
    end
  end
end
