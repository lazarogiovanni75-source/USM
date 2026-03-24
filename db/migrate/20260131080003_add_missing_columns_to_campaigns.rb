class AddMissingColumnsToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :start_date, :date
    add_column :campaigns, :end_date, :date
    add_column :campaigns, :budget, :decimal, precision: 10, scale: 2
    add_column :campaigns, :target_audience, :text
    add_column :campaigns, :platforms, :text
    add_column :campaigns, :content_count, :integer
    add_column :campaigns, :hashtag_set, :text
    add_column :campaigns, :mentions, :text
    add_column :campaigns, :content_pillars, :text
    add_column :campaigns, :goal_value, :decimal, precision: 10, scale: 2
    add_column :campaigns, :kpis, :text
    add_column :campaigns, :success_metrics, :json
    add_column :campaigns, :budget_allocation, :json
    add_column :campaigns, :brand_guidelines, :text
    add_column :campaigns, :competitors, :text
    add_column :campaigns, :influencer_targets, :text
    add_column :campaigns, :key_messages, :text
  end
end
