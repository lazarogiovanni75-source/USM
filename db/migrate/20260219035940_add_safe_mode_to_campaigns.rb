# frozen_string_literal: true

class AddSafeModeToCampaigns < ActiveRecord::Migration[7.2]
  def change
    add_column :campaigns, :safe_mode, :boolean, default: true
    add_column :campaigns, :failure_count, :integer, default: 0
  end
end
