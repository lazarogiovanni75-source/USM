# frozen_string_literal: true

class CompetitorTrackingJob < ApplicationJob
  queue_as :default

  def perform(competitor_id = nil)
    if competitor_id
      competitor = Competitor.find(competitor_id)
      CompetitorTrackingService.track_competitor(competitor)
    else
      CompetitorTrackingService.refresh_all_metrics
    end
  end
end