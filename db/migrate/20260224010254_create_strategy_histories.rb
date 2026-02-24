class CreateStrategyHistories < ActiveRecord::Migration[7.2]
  def change
    create_table :strategy_histories do |t|
      t.references :user
      t.string :focus_area, default: "comprehensive"
      t.jsonb :metrics
      t.jsonb :strategy
      t.jsonb :insights
      t.text :recommendations
      t.jsonb :kpis_tracked
      t.integer :overall_score, default: 0
      t.string :generated_by, default: "manual"
      t.datetime :generated_at


      t.timestamps
    end
  end
end
