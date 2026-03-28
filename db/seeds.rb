# Seeds file for production - minimal data only
# This file creates essential configuration data

# Wrap everything in a transaction for safety
ActiveRecord::Base.transaction do
  puts "Starting production seeds..."

  # Create AI System Prompt setting
  puts "Creating AI system prompt setting..."

  ai_prompt = <<~PROMPT
You are Pilot, an AI marketing assistant designed to help users with social media management and marketing tasks.

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
- Voice Commands via Pilot
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

setting = SiteSetting.find_or_initialize_by(key: 'ai_system_prompt')
setting.value = ai_prompt
setting.save!

# Create default subscription plans
puts "Creating subscription plans..."

starter = SubscriptionPlan.find_or_initialize_by(name: 'Starter')
starter.price_cents = 4000
starter.credits = 40
starter.features = "Multi-platform publishing (3 platforms)\nCampaign management (4 campaigns)\n40 posts/month\nEmail Content Approvals (AI generates → email you approve)\nOne-click Post Now or Schedule\nAI content generation\nAI image generation\nAI video generation\nBasic analytics\nMedia library & templates"
starter.save!

entrepreneur = SubscriptionPlan.find_or_initialize_by(name: 'Entrepreneur')
entrepreneur.price_cents = 8000
entrepreneur.credits = 80
entrepreneur.features = "Multi-platform publishing (6 platforms)\nCampaign management (8 campaigns)\n80 posts/month\nEmail Content Approvals with full workflow\nAI content ideas (tell AI what to do)\nVoice Commands via Pilot\nWorkflow Automation\nAdvanced Analytics (trends, competitor)\nContent Approval Workflows\nRecurring scheduling\nCampaign Wizard + Templates\nAll Starter features included"
entrepreneur.save!

pro = SubscriptionPlan.find_or_initialize_by(name: 'Pro')
pro.price_cents = 12000
pro.credits = 120
pro.features = "Multi-platform publishing (9 platforms)\nCampaign management (12 campaigns)\n120 posts/month\nFull AI Automation (autonomous autopilot)\nPremium Analytics (predictions, A/B testing, sentiment)\nDiscovery Tools (hashtags, influencers, products)\nAll Entrepreneur features included"
pro.save!

  puts "Production seeds completed!"
  puts "Subscription Plans: #{SubscriptionPlan.count}"
end
