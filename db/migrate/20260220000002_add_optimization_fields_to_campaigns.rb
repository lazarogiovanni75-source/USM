# frozen_string_literal: true

# Migration to add optimization fields to Campaign
class AddOptimizationFieldsToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :last_optimized_at, :datetime
    add_column :campaigns, :consecutive_decline_cycles, :integer, default: 0
    add_column :campaigns, :published_posts_count, :integer, default: 0
  end
end
