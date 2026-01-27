class CreateTrendAnalyses < ActiveRecord::Migration[7.2]
  def change
    create_table :trend_analyses, force: true do |t|
      t.belongs_to :user, null: false
      t.string :analysis_type
      t.json :data
      t.decimal :trend_score
      t.text :insights

      t.timestamps
    end
    add_index :trend_analyses, :user_id, if_not_exists: true
    add_index :trend_analyses, :analysis_type, if_not_exists: true
  end
end
