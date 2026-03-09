# Seeds file for production - minimal data only
# This file creates essential configuration data

require 'open-uri'

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
- 3 social platforms
- 4 campaigns max
- 40 posts/month limit
- AI content generation (manual prompts)
- AI image generation
- AI video generation
- Basic analytics
- Media library & templates

### Entrepreneur Plan ($80/month)
- 6 social platforms
- 8 campaigns max
- 80 posts/month limit
- AI content ideas (tell AI what to do)
- Voice Commands via Otto-Pilot
- Workflow Automation
- Advanced Analytics (trends, competitor)
- Content Approval Workflows
- Recurring scheduling

### Pro Plan ($120/month)
- 9 social platforms
- 12 campaigns max
- 120 posts/month limit
- Full AI Automation (autonomous autopilot)
- Premium Analytics (predictions, A/B testing, sentiment)
- Discovery Tools (hashtags, influencers, products)
- All Entrepreneur features included

## CONTENT GENERATION GUIDELINES
- Always follow platform-specific best practices
- Use appropriate tone for each platform
- Include relevant hashtags (2-5 for Twitter, 5-10 for Instagram)
- Keep posts within character limits
- Suggest images/videos when appropriate
- Always offer to schedule posts for optimal times

## CAMPAIGN MANAGEMENT
- Help users create campaigns with clear goals
- Suggest appropriate campaign types based on objectives
- Track and report campaign performance
- Recommend adjustments based on analytics
PROMPT

SiteSetting.find_or_create_by!(key: 'ai_system_prompt') do |setting|
  setting.value = ai_prompt
end

# Create default subscription plans
puts "Creating subscription plans..."

SubscriptionPlan.find_or_create_by!(name: 'Starter') do |plan|
  plan.price_cents = 4000
  plan.credits = 40
  plan.features = "Multi-platform publishing (3 platforms)\nCampaign management (4 campaigns)\n40 posts/month\nAI content generation\nAI image generation\nAI video generation\nBasic analytics\nMedia library & templates"
end

SubscriptionPlan.find_or_create_by!(name: 'Entrepreneur') do |plan|
  plan.price_cents = 8000
  plan.credits = 80
  plan.features = "Multi-platform publishing (6 platforms)\nCampaign management (8 campaigns)\n80 posts/month\nAI content ideas (tell AI what to do)\nVoice Commands via Otto-Pilot\nWorkflow Automation\nAdvanced Analytics (trends, competitor)\nContent Approval Workflows\nRecurring scheduling\nAll Starter features included"
end

SubscriptionPlan.find_or_create_by!(name: 'Pro') do |plan|
  plan.price_cents = 12000
  plan.credits = 120
  plan.features = "Multi-platform publishing (9 platforms)\nCampaign management (12 campaigns)\n120 posts/month\nFull AI Automation (autonomous autopilot)\nPremium Analytics (predictions, A/B testing, sentiment)\nDiscovery Tools (hashtags, influencers, products)\nAll Entrepreneur features included"
end

puts "Production seeds completed!"
puts "Subscription Plans: #{SubscriptionPlan.count}"
