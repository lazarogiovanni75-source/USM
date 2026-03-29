# frozen_string_literal: true

module QualityTiers
  extend ActiveSupport::Concern

  QUALITY_TIERS = {
    "standard" => {
      label: "Standard",
      description: "Great for everyday posts, social media content, and drafts",
      resolution: "720p / 1024x1024",
      credit_cost: 1,
      badge: nil,
      icon: "⚡",
      atlas_quality: "standard"
    },
    "hd" => {
      label: "HD",
      description: "High definition output. Perfect for ads, hero images, and premium content",
      resolution: "1080p / 2048x2048",
      credit_cost: 2,
      badge: "HD",
      icon: "✨",
      atlas_quality: "hd"
    }
  }.freeze

  CREDIT_COSTS = {
    image: { standard: 1, hd: 2 },
    video: { standard: 2, hd: 4 }
  }.freeze

  def self.credit_cost_for(media_type, quality)
    CREDIT_COSTS.dig(media_type.to_sym, quality.to_sym) || 1
  end

  def self.tier_info(quality)
    QUALITY_TIERS[quality.to_s] || QUALITY_TIERS["standard"]
  end

  def self.valid_qualities
    QUALITY_TIERS.keys
  end

  def self.valid_quality?(quality)
    QUALITY_TIERS.key?(quality.to_s)
  end
end
