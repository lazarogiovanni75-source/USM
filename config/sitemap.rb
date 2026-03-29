# Sitemap configuration for UltimateSocialMedia
# Run `rake sitemap:generate` to generate sitemap
# Run `rake sitemap:refresh` to generate and ping search engines

SitemapGenerator::Sitemap.default_host = "https://ultimatesocialmedia01.com"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"

SitemapGenerator::Sitemap.create do
  # Static pages
  add root_path, changefreq: "daily", priority: 1.0
  add features_path, changefreq: "weekly", priority: 0.9
  add pricing_path, changefreq: "weekly", priority: 0.9
  add about_path, changefreq: "monthly", priority: 0.7
  add faq_path, changefreq: "monthly", priority: 0.6
  add terms_of_service_path, changefreq: "yearly", priority: 0.3
  add privacy_policy_path, changefreq: "yearly", priority: 0.3

  # User-facing pages (if signed in)
  if defined?(User)
    # Assistants
    if defined?(Assistant)
      Assistant.find_each do |assistant|
        add assistant_path(assistant), updated_at: assistant.updated_at, changefreq: "weekly", priority: 0.8
      end
    end

    # Campaigns
    if defined?(Campaign)
      Campaign.find_each do |campaign|
        add campaign_path(campaign), updated_at: campaign.updated_at, changefreq: "weekly", priority: 0.7
      end
    end

    # Posts
    if defined?(Post)
      Post.find_each do |post|
        add post_path(post), updated_at: post.updated_at, changefreq: "monthly", priority: 0.6
      end
    end

    # Brand Voices
    if defined?(BrandVoice)
      BrandVoice.find_each do |brand_voice|
        add brand_voice_path(brand_voice), updated_at: brand_voice.updated_at, changefreq: "monthly", priority: 0.6
      end
    end
  end
end
