# Campaign Templates Seed Data
# Run with: rails runner db/seeds/campaign_templates_seed.rb

puts "Seeding campaign templates..."

PLATFORMS = ['instagram', 'facebook', 'tiktok', 'linkedin', 'x', 'pinterest', 'youtube', 'threads', 'bluesky'].freeze

# Product Launch Campaign (7 days)
product_launch_structure = {
  theme: "Product Launch",
  platforms: PLATFORMS,
  days: [
    { day: 1, title: "Announcement Day", theme: "Build curiosity", caption_template: "Something big is coming. We built an AI that runs your entire social media. Content. Images. Videos. Scheduling. All automated. Follow us to be first.", post_time: "10:00 AM", content_type: "teaser" },
    { day: 2, title: "Problem Day", theme: "Create pain awareness", caption_template: "Be honest. How many hours did you spend on social media this week? Creating content. Writing captions. Scheduling posts. Now multiply that by 52 weeks. That's your year.", post_time: "2:00 PM", content_type: "pain_point" },
    { day: 3, title: "Solution Day", theme: "Introduce the product", caption_template: "Introducing [PRODUCT_NAME]. The AI platform that creates, schedules, and posts your content across 9 platforms automatically. Launch offer: 50% off with code [PROMO_CODE]", post_time: "12:00 PM", content_type: "announcement" },
    { day: 4, title: "Social Proof Day", theme: "Build trust", caption_template: "Our early users are already seeing results. If you haven't signed up yet, use code [PROMO_CODE] to get 50% off your first month.", post_time: "11:00 AM", content_type: "social_proof" },
    { day: 5, title: "Features Day", theme: "Educate", caption_template: "Here is everything [PRODUCT_NAME] does for you: AI Content Creation, AI Image and Video Generation, Campaign Builder, Auto Scheduling, 9 Platform Posting, Analytics Dashboard.", post_time: "1:00 PM", content_type: "features" },
    { day: 6, title: "Urgency Day", theme: "Drive conversions", caption_template: "Last 24 hours to get 50% off. After tomorrow the price goes back to full. Use code [PROMO_CODE] now.", post_time: "9:00 AM", content_type: "urgency" },
    { day: 7, title: "Last Chance Day", theme: "Final push", caption_template: "Today is the LAST DAY to get [PRODUCT_NAME] at 50% off. Code [PROMO_CODE] expires at midnight tonight.", post_time: "10:00 AM", content_type: "last_chance" }
  ]
}

CampaignTemplate.find_or_create_by!(name: "Product Launch Campaign", category: "product") do |t|
  t.description = "A 7-day campaign to launch a new product. Builds curiosity, addresses pain points, introduces your product, provides social proof, educates on features, and drives conversions with urgency."
  t.duration_days = 7
  t.structure = product_launch_structure
  t.is_active = true
end
puts "Product Launch Campaign created"

# Holiday Sale Campaign (7 days)
holiday_sale_structure = {
  theme: "Holiday Sale",
  platforms: PLATFORMS,
  days: [
    { day: 1, title: "Countdown Begins", theme: "Build anticipation", caption_template: "[HOLIDAY_NAME] Countdown Starts! Only 7 days until our biggest sale! Every day this week exclusive deals you won't want to miss.", post_time: "10:00 AM", content_type: "countdown" },
    { day: 2, title: "Sneak Peek", theme: "Create desire", caption_template: "Sneak peek at just SOME of our [HOLIDAY_NAME] deals. We're talking up to 50% off our bestsellers! Come back tomorrow for the full reveal!", post_time: "2:00 PM", content_type: "sneak_peek" },
    { day: 3, title: "Main Event", theme: "Launch the sale", caption_template: "IT'S HERE! Our [HOLIDAY_NAME] Sale is LIVE! Use code [PROMO_CODE] for [DISCOUNT_PERCENT]% off everything! Shop now before deals end on [END_DATE].", post_time: "12:00 PM", content_type: "sale_launch" },
    { day: 4, title: "Best Seller Spotlight", theme: "Feature popular items", caption_template: "Our [HOLIDAY_NAME] Best Sellers are flying off the shelves! Grab yours before they're gone! Use code [PROMO_CODE] for [DISCOUNT_PERCENT]% off.", post_time: "11:00 AM", content_type: "spotlight" },
    { day: 5, title: "Limited Stock Alert", theme: "Create urgency", caption_template: "STOCK ALERT! Several items are selling out FAST. Our [HOLIDAY_NAME] sale ends [END_DATE]. Don't miss out! Use code [PROMO_CODE].", post_time: "1:00 PM", content_type: "urgency" },
    { day: 6, title: "Gift Guide", theme: "Help with gifting", caption_template: "[HOLIDAY_NAME] Gift Guide! Still need gift ideas? We've got you covered! Use code [PROMO_CODE] for [DISCOUNT_PERCENT]% off.", post_time: "11:00 AM", content_type: "gift_guide" },
    { day: 7, title: "Final Day", theme: "Last chance push", caption_template: "LAST DAY of our [HOLIDAY_NAME] Sale! Tonight at midnight, [DISCOUNT_PERCENT]% off ends. Use code [PROMO_CODE] before it's too late!", post_time: "10:00 AM", content_type: "last_chance" }
  ]
}

CampaignTemplate.find_or_create_by!(name: "Holiday Sale Campaign", category: "sales") do |t|
  t.description = "A 7-day campaign for holiday sales events. Creates anticipation, reveals deals, drives urgency, and pushes final conversions before the sale ends."
  t.duration_days = 7
  t.structure = holiday_sale_structure
  t.is_active = true
end
puts "Holiday Sale Campaign created"

# Brand Awareness Campaign (14 days)
brand_awareness_structure = {
  theme: "Brand Awareness",
  platforms: PLATFORMS,
  days: [
    { day: 1, title: "Introduction", theme: "Introduce brand", caption_template: "Hey there! We're [BRAND_NAME], and we're excited to finally share what we've been working on. Stick around to learn more!", post_time: "10:00 AM", content_type: "introduction" },
    { day: 2, title: "Mission Day", theme: "Share values", caption_template: "We started [BRAND_NAME] because we believe in [BRAND_VALUE]. That's not just what we sell - it's who we are. What values drive your business?", post_time: "2:00 PM", content_type: "mission" },
    { day: 3, title: "Behind the Scenes", theme: "Humanize brand", caption_template: "Ever wonder who's behind [BRAND_NAME]? Meet the team! We're dedicated to [BRAND_GOAL]. Get to know us!", post_time: "11:00 AM", content_type: "bts" },
    { day: 4, title: "Process Day", theme: "Show expertise", caption_template: "You might use our product every day, but do you know HOW it works? Here's a look at our process. Quality matters to us.", post_time: "1:00 PM", content_type: "process" },
    { day: 5, title: "Community Focus", theme: "Build connection", caption_template: "At [BRAND_NAME], you're more than a customer - you're part of our community. Share in the comments: What's your favorite [INDUSTRY] tip?", post_time: "11:00 AM", content_type: "community" },
    { day: 6, title: "Milestone", theme: "Celebrate achievements", caption_template: "[BRAND_NAME] just hit [MILESTONE]! Thank YOU for being part of our journey. Here's to the next one!", post_time: "10:00 AM", content_type: "milestone" },
    { day: 7, title: "Customer Spotlight", theme: "Feature customers", caption_template: "Meet one of our amazing customers! Want to be featured? Share your story with us!", post_time: "2:00 PM", content_type: "testimonial" },
    { day: 8, title: "Education Day", theme: "Share knowledge", caption_template: "Want to level up your [SKILL] game? Here are tips that changed how we think about [TOPIC].", post_time: "1:00 PM", content_type: "educational" },
    { day: 9, title: "Partnership Day", theme: "Announce partnerships", caption_template: "Big news! [BRAND_NAME] is partnering with [PARTNER_NAME] to bring you [BENEFIT]. Stay tuned for exciting collabs!", post_time: "11:00 AM", content_type: "partnership" },
    { day: 10, title: "Culture Day", theme: "Show company culture", caption_template: "Work hard, play hard! Here's a look at life at [BRAND_NAME]. Our culture is built on [CULTURE_VALUES].", post_time: "3:00 PM", content_type: "culture" },
    { day: 11, title: "Innovation Day", theme: "Showcase innovation", caption_template: "What's next for [BRAND_NAME]? We've been working on something big and can't wait to share it with you.", post_time: "10:00 AM", content_type: "innovation" },
    { day: 12, title: "Giving Back", theme: "Show social responsibility", caption_template: "At [BRAND_NAME], we believe in giving back. For every purchase this month, we're donating to [CHARITY_CAUSE].", post_time: "2:00 PM", content_type: "cause" },
    { day: 13, title: "Appreciation Day", theme: "Thank audience", caption_template: "You. Yes, YOU! Thank you for following, engaging, and believing in [BRAND_NAME]. We've grown so much.", post_time: "11:00 AM", content_type: "appreciation" },
    { day: 14, title: "Recap & Future", theme: "Wrap up campaign", caption_template: "What a journey it's been! Here's everything we've shared over the past 14 days. This is just the beginning for [BRAND_NAME].", post_time: "10:00 AM", content_type: "recap" }
  ]
}

CampaignTemplate.find_or_create_by!(name: "Brand Awareness Campaign", category: "branding") do |t|
  t.description = "A 14-day campaign to build brand awareness and establish your brand identity. Includes introduction, mission, behind-the-scenes, community building, and future teaser content."
  t.duration_days = 14
  t.structure = brand_awareness_structure
  t.is_active = true
end
puts "Brand Awareness Campaign created"

# New Product Teaser Campaign (5 days)
new_product_teaser_structure = {
  theme: "New Product Teaser",
  platforms: PLATFORMS,
  days: [
    { day: 1, title: "Teaser Reveal", theme: "Build mystery", caption_template: "Something's coming... We've been working on this for months and we can't wait to show you. Stay tuned. It's going to be worth the wait. Follow for updates!", post_time: "10:00 AM", content_type: "teaser" },
    { day: 2, title: "Hint Day", theme: "Give subtle clues", caption_template: "Still thinking about what we have coming... Here are a few hints: It's something you've been asking for. It's going to change how you [BENEFIT]. You'll want to tell all your friends about it.", post_time: "2:00 PM", content_type: "hint" },
    { day: 3, title: "Feature Preview", theme: "Tease key features", caption_template: "Can't keep it secret anymore! Our new product will help you [KEY_BENEFIT]. Here's a sneak peek at what it can do: [FEATURE_1], [FEATURE_2], [FEATURE_3]. Launching in 2 days!", post_time: "12:00 PM", content_type: "preview" },
    { day: 4, title: "Countdown", theme: "Create excitement", caption_template: "24 HOURS! [PRODUCT_NAME] drops TOMORROW and we're counting down the hours! Get ready for the launch you've been waiting for. Use code [PROMO_CODE] for early access!", post_time: "10:00 AM", content_type: "countdown" },
    { day: 5, title: "Launch Day", theme: "Official launch", caption_template: "IT'S HERE! Introducing [PRODUCT_NAME] - [PRODUCT_TAGLINE]. [PRODUCT_DESCRIPTION]. Get [DISCOUNT_PERCENT]% off with code [PROMO_CODE]! Link in bio!", post_time: "9:00 AM", content_type: "launch" }
  ]
}

CampaignTemplate.find_or_create_by!(name: "New Product Teaser Campaign", category: "product") do |t|
  t.description = "A 5-day campaign to teaser a new product launch. Builds anticipation with mysteries, hints, feature previews, and culminates in the official launch."
  t.duration_days = 5
  t.structure = new_product_teaser_structure
  t.is_active = true
end
puts "New Product Teaser Campaign created"

# Weekly Engagement Campaign (7 days)
weekly_engagement_structure = {
  theme: "Weekly Engagement",
  platforms: PLATFORMS,
  days: [
    { day: 1, title: "Motivation Monday", theme: "Start the week strong", caption_template: "Good morning! It's a new week and new opportunities. What's your main goal this week? Drop it in the comments and let's crush it together!", post_time: "8:00 AM", content_type: "motivation" },
    { day: 2, title: "Tip Tuesday", theme: "Share valuable tips", caption_template: "Tuesday Tip! Here's something that helped us [ACHIEVEMENT]: [TIP_CONTENT]. Save this for later! And share your best tips in the comments.", post_time: "11:00 AM", content_type: "tip" },
    { day: 3, title: "Thoughtful Thursday", theme: "Start conversations", caption_template: "We want to hear from you! [QUESTION]? Let us know in the comments. We read every single one!", post_time: "2:00 PM", content_type: "question" },
    { day: 4, title: "Feature Friday", theme: "Highlight features/benefits", caption_template: "Feature Friday! Did you know [BRAND_NAME] can help you [FEATURE_BENEFIT]? Here's how: [FEATURE_DESCRIPTION]. Have you tried it yet?", post_time: "12:00 PM", content_type: "feature" },
    { day: 5, title: "Story Saturday", theme: "Share stories", caption_template: "Story Saturday! [BRAND_STORY]. This is why we do what we do. Thank you for being part of our story.", post_time: "10:00 AM", content_type: "story" },
    { day: 6, title: "Success Sunday", theme: "Celebrate wins", caption_template: "Sunday Success Stories! [CUSTOMER_SUCCESS]. Want to share your success story? DM us! #CustomerWins #Success", post_time: "11:00 AM", content_type: "success" },
    { day: 7, title: "Week Wrap Up", theme: "Engage with audience", caption_template: "That's a wrap on another week! What was your favorite post this week? Let us know below! Next week we have more great content coming. Stay tuned!", post_time: "6:00 PM", content_type: "wrap_up" }
  ]
}

CampaignTemplate.find_or_create_by!(name: "Weekly Engagement Campaign", category: "engagement") do |t|
  t.description = "A 7-day recurring engagement campaign with themed content days. Motivation Monday, Tip Tuesday, Thoughtful Thursday, Feature Friday, Story Saturday, Success Sunday, and Week Wrap Up."
  t.duration_days = 7
  t.structure = weekly_engagement_structure
  t.is_active = true
end
puts "Weekly Engagement Campaign created"

puts "All campaign templates seeded successfully!"
