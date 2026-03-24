# frozen_string_literal: true

class CreateCampaignUsages < ActiveRecord::Migration[7.2]
  def change
    create_table :campaign_usages do |t|
      t.references :campaign, null: false, foreign_key: true
      t.integer :llm_tokens, default: 0
      t.integer :images_generated, default: 0
      t.integer :posts_published, default: 0
      t.integer :api_calls, default: 0
      t.decimal :estimated_cost, precision: 10, scale: 2, default: 0
      t.timestamps
    end
  end
end
