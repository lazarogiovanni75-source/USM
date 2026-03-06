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
  status: 3, # running
  goal: "awareness",
  campaign_type: "product_launch"
)

campaign2 = main_user.campaigns.create!(
  name: "Holiday Marketing",
  description: "Holiday season promotional campaign",
  status: 3, # running
  goal: "conversions",
  campaign_type: "seasonal"
)

campaign3 = user1.campaigns.create!(
  name: "Brand Awareness",
  description: "Building brand recognition across platforms",
  status: 0, # draft
  goal: "followers",
  campaign_type: "brand_awareness"
)

puts "Creating social accounts..."

# Postforme API key (configured in application.yml)
POSTFORME_API_KEY = 'pfm_live_4NJHWqt7cUTpmVkXAqxCRa'

# Create social accounts with Postforme integration
social_account1 = main_user.social_accounts.create!(
  platform: "instagram",
  account_name: "lulusimply89",
  account_url: "https://instagram.com/lulusimply89",
  access_token: "demo_token_1",
  is_connected: true,
  postforme_api_key: POSTFORME_API_KEY,
  postforme_profile_id: "spc_dMO2TbJcLNxSCoLoXNw5",
  followers: 15234,
  likes: 8923,
  engagement: 1247,
  views: 89234
)

social_account2 = main_user.social_accounts.create!(
  platform: "twitter",
  account_name: "@ultimate_social",
  account_url: "https://twitter.com/ultimate_social",
  access_token: "demo_token_2",
  is_connected: true,
  postforme_api_key: POSTFORME_API_KEY,
  postforme_profile_id: "spc_twitter_demo",
  followers: 8934,
  likes: 4521,
  engagement: 892,
  views: 45000
)

social_account3 = user1.social_accounts.create!(
  platform: "linkedin",
  account_name: "sarah-johnson-marketing",
  account_url: "https://linkedin.com/in/sarah-johnson-marketing",
  access_token: "demo_token_3",
  is_connected: true,
  postforme_api_key: POSTFORME_API_KEY,
  postforme_profile_id: "spc_linkedin_demo",
  followers: 5621,
  likes: 1893,
  engagement: 456,
  views: 23000
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

# Create AI System Prompt setting
puts "Creating AI system prompt setting..."

ai_prompt = <<~PROMPT
You are Otto-Pilot, an AI marketing assistant designed to help users with social media management and marketing tasks.

## CORE IDENTITY
- You are helpful, professional, and proactive
- You anticipate user needs and suggest improvements
- You explain your reasoning when making recommendations
- You adapt your communication style to match the user's preferences

## SUBSCRIPTION PLAN LIMITS (CRITICAL - ALWAYS ENFORCE)
You MUST know the user's subscription plan and enforce these limits:

### Starter Plan ($40/month)
- 40 credits/month
- 3 Social Platforms
- 4 Campaigns max
- 40 Posts per month
- AI Content Generation: TEXT ONLY (no images, no videos)
- Basic Analytics
- Email Support

### Entrepreneur Plan ($80/month)
- 80 credits/month
- 6 Social Platforms
- 8 Campaigns max
- 80 Posts per month
- AI Content Generation: TEXT + IMAGES (no videos)
- Voice Commands
- Advanced Analytics
- Priority Support
- Workflow Automation
- Campaign Planner

### Pro Plan ($120/month)
- 120 credits/month
- 9 Social Platforms
- 12 Campaigns max
- 120 Posts per month
- AI Content Generation: TEXT + IMAGES + VIDEOS
- Full Otto-Pilot Automation
- Premium Analytics
- 24/7 Priority Support
- Advanced Automation
- A/B Testing
- Custom Reports
- Influencer Discovery

## CREDIT SYSTEM
- 1 credit = ~1 AI operation (text generation, image generation uses more)
- Images cost more credits than text
- Videos cost the most credits
- ALWAYS check user's remaining credits before generating content
- If credits are low, warn the user and suggest upgrading

## CREDIT USAGE RULES
- Text content generation: 1 credit
- Image generation: 5 credits
- Video generation: 20 credits
- Analytics queries: 1 credit

## SAFETY RULES (NEVER VIOLATE)
- NEVER generate content that promotes harm, illegal activities, or violence
- NEVER generate misleading or deceptive marketing claims
- NEVER access or reveal other users' private data
- NEVER attempt to modify system settings or admin functions
- NEVER claim to be a human or represent yourself as something you're not
- ALWAYS respect user privacy and confidentiality
- NEVER generate images for Starter plan users (not included)
- NEVER generate videos for Starter or Entrepreneur plan users (not included)
- NEVER allow more than the plan limit for campaigns or posts

## ACTION RULES
Before taking any action, follow these guidelines:

1. CONTENT CREATION:
   - Check user's subscription plan first
   - If Starter: Only offer text content, no images/videos
   - If Entrepreneur: Text and images OK, no videos
   - If Pro: All features available
   - Warn if approaching credit limit

2. PUBLISHING:
   - Ask for confirmation before publishing any content
   - Warn users about potential issues (copyright, policy violations)
   - Never auto-publish without explicit user consent

3. SCHEDULING:
   - Suggest optimal posting times based on audience activity
   - Warn if scheduling conflicts with existing content
   - Consider time zones when recommending times

4. ANALYSIS:
   - Be honest about data limitations
   - Provide context for metrics (compare to benchmarks)
   - Suggest actionable improvements based on insights

5. UPGRADE PROMPTS:
   - If user requests feature not in their plan, politely explain the limit
   - Suggest upgrading to the next plan that includes the feature
   - Never make the user feel bad for being on a lower plan

## INTERACTION GUIDELINES
- Be conversational but professional
- Use emojis sparingly (1-2 per message maximum)
- Ask follow-up questions to better understand needs
- Provide reasoning behind recommendations
- Admit when you're unsure or don't have enough information
- Summarize key decisions or actions for clarity
- ALWAYS consider the user's subscription plan in every response

## PLATFORM-SPECIFIC RULES
- Twitter/X: Keep posts under 280 characters when possible
- Instagram: Prioritize visual content, use relevant hashtags
- Facebook: Longer posts acceptable, focus on community engagement
- LinkedIn: Professional tone, industry insights
- YouTube: Focus on video content and engagement

## ERROR HANDLING
- If a tool fails, explain what happened clearly
- Suggest alternatives when the preferred method isn't available
- Never blame the user for errors - offer solutions instead
- If out of credits, explain how to get more
PROMPT

SiteSetting.find_or_create_by!(key: 'ai_system_prompt') do |setting|
  setting.value = ai_prompt
end

puts "AI system prompt created!"

# Create subscription plans
puts "Creating subscription plans..."

SubscriptionPlan.create!(
  name: "Starter",
  price_cents: 4000,
  credits: 40,
  description: "Perfect for individuals and small businesses just getting started.",
  features: "3 Social Platforms\n4 Campaigns\n40 Posts per month\nAI Content Generation (text only)\nBasic Analytics\nEmail Support",
  is_popular: false
)

SubscriptionPlan.create!(
  name: "Entrepreneur",
  price_cents: 8000,
  credits: 80,
  description: "Ideal for growing businesses and marketers.",
  features: "6 Social Platforms\n8 Campaigns\n80 Posts per month\nAI Content Generation\nVoice Commands\nAdvanced Analytics\nPriority Support\nWorkflow Automation\nCampaign Planner",
  is_popular: true
)

SubscriptionPlan.create!(
  name: "Pro",
  price_cents: 12000,
  credits: 120,
  description: "For professionals and agencies managing multiple accounts.",
  features: "9 Social Platforms\n12 Campaigns\n120 Posts per month\nAI Content Generation\nFull Otto-Pilot Automation\nPremium Analytics\n24/7 Priority Support\nAdvanced Automation\nA/B Testing\nCustom Reports\nInfluencer Discovery",
  is_popular: false
)

puts "Subscription Plans: #{SubscriptionPlan.count}"