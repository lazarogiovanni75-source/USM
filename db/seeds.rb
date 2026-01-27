# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# IMPORTANT: Do NOT add Administrator data here!
# Administrator accounts should be created manually by user.
# This seeds file is only for application data (products, categories, etc.)

require 'open-uri'

# Create test users for development
puts "Creating users..."

# Main test user
main_user = User.create!(
  name: "Demo User",
  email: "demo@#{Time.now.to_i}example.com",
  password: "password123",
  password_confirmation: "password123",
  verified: true
)

# Additional test users
user1 = User.create!(
  name: "Sarah Johnson",
  email: "sarah@#{Time.now.to_i}example.com", 
  password: "password123",
  password_confirmation: "password123",
  verified: true
)

user2 = User.create!(
  name: "Mike Chen",
  email: "mike@#{Time.now.to_i}example.com",
  password: "password123", 
  password_confirmation: "password123",
  verified: true
)

puts "Creating campaigns..."

# Create campaigns for each user
campaign1 = main_user.campaigns.create!(
  name: "Product Launch Q1",
  description: "Launching our new social media management features",
  status: "active",
  goal: "Increase brand awareness",
  campaign_type: "product_launch"
)

campaign2 = main_user.campaigns.create!(
  name: "Holiday Marketing",
  description: "Holiday season promotional campaign",
  status: "active", 
  goal: "Boost holiday sales",
  campaign_type: "promotion"
)

campaign3 = user1.campaigns.create!(
  name: "Brand Awareness",
  description: "Building brand recognition across platforms",
  status: "draft",
  goal: "Increase followers",
  campaign_type: "awareness"
)

puts "Creating social accounts..."

# Create social accounts
social_account1 = main_user.social_accounts.create!(
  platform: "instagram",
  account_name: "@ultimatesocial",
  account_url: "https://instagram.com/ultimatesocial",
  access_token: "demo_token_1",
  is_connected: true
)

social_account2 = main_user.social_accounts.create!(
  platform: "twitter",
  account_name: "@ultimate_social",
  account_url: "https://twitter.com/ultimate_social",
  access_token: "demo_token_2", 
  is_connected: true
)

social_account3 = user1.social_accounts.create!(
  platform: "linkedin",
  account_name: "sarah-johnson-marketing",
  account_url: "https://linkedin.com/in/sarah-johnson-marketing",
  access_token: "demo_token_3",
  is_connected: true
)

puts "Creating content..."

# Create sample content
content1 = main_user.contents.create!(
  title: "Introducing Ultimate Social Media Platform",
  body: "We're excited to launch our revolutionary social media management platform with AI-powered automation. Say goodbye to manual posting and hello to intelligent content strategy! 🚀 #SocialMedia #AI #Marketing",
  content_type: "post",
  platform: "instagram",
  status: "approved",
  campaign: campaign1
)

content2 = main_user.contents.create!(
  title: "Why Automation Matters",
  body: "Did you know that automated social media posts can increase engagement by up to 150%? Our AI-powered platform helps you create, schedule, and optimize your content for maximum impact.",
  content_type: "post", 
  platform: "twitter",
  status: "draft",
  campaign: campaign1
)

content3 = main_user.contents.create!(
  title: "Holiday Campaign Success Stories",
  body: "This holiday season, our clients saw an average 200% increase in engagement with our AI-generated content. Here's how they did it... 🎄✨",
  content_type: "video",
  platform: "facebook", 
  status: "approved",
  campaign: campaign2
)

content4 = user1.contents.create!(
  title: "Building Your Brand Voice",
  body: "Consistent brand voice across all platforms is crucial for recognition. Our platform helps you maintain your unique voice while optimizing for each platform's audience.",
  content_type: "post",
  platform: "linkedin",
  status: "draft",
  campaign: campaign3
)

puts "Creating scheduled posts..."

# Create scheduled posts
scheduled_post1 = ScheduledPost.create!(
  content: content1,
  social_account: social_account1,
  user: main_user,
  scheduled_at: 2.days.from_now,
  status: "scheduled"
)

scheduled_post2 = ScheduledPost.create!(
  content: content2,
  social_account: social_account2,
  user: main_user,
  scheduled_at: 1.day.from_now,
  status: "scheduled"
)

scheduled_post3 = ScheduledPost.create!(
  content: content3,
  social_account: social_account1,
  user: main_user,
  scheduled_at: 3.days.from_now,
  status: "scheduled"
)

puts "Creating performance metrics..."

# Create performance metrics (associated with scheduled posts)
scheduled_post1.performance_metrics.create!(
  impressions: 1250,
  likes: 85,
  comments: 12,
  shares: 8,
  engagement_rate: 0.68,
  reach: 1100
)

scheduled_post2.performance_metrics.create!(
  impressions: 8500,
  likes: 420,
  comments: 85,
  shares: 45,
  engagement_rate: 0.65,
  reach: 7500
)

scheduled_post3.performance_metrics.create!(
  impressions: 3200,
  likes: 180,
  comments: 25,
  shares: 32,
  engagement_rate: 0.74,
  reach: 2900
)

puts "Creating voice commands..."

# Create voice commands
main_user.voice_commands.create!(
  command: "Create a new campaign for product launch",
  status: "completed",
  command_type: "create_campaign",
  response_text: "Successfully created new campaign 'Product Launch Q2'",
  ai_confidence: 0.95
)

main_user.voice_commands.create!(
  command: "Generate social media content about automation",
  status: "completed", 
  command_type: "generate_content",
  response_text: "Generated 3 social media posts about automation benefits",
  ai_confidence: 0.92
)

puts "Seed data created successfully!"
puts "Users: #{User.count}"
puts "Campaigns: #{Campaign.count}"
puts "Contents: #{Content.count}"
puts "Social Accounts: #{SocialAccount.count}"
puts "Scheduled Posts: #{ScheduledPost.count}"