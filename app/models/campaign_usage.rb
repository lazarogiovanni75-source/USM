# frozen_string_literal: true

class CampaignUsage < ApplicationRecord
  belongs_to :campaign

  validates :campaign_id, uniqueness: true
end
