# frozen_string_literal: true

class AddRetryFieldsToCampaignTasks < ActiveRecord::Migration[7.2]
  def change
    add_column :campaign_tasks, :retry_count, :integer, default: 0
    add_column :campaign_tasks, :last_error, :text
  end
end
