FactoryBot.define do
  factory :brand_profile do

    association :user
    business_name { "MyString" }
    industry { "MyString" }
    website_url { "MyString" }
    products_services { "MyText" }
    content_tone { "MyString" }
    posting_topics { "MyText" }
    topics_to_avoid { "MyText" }
    onboarding_completed { true }
    onboarding_dismissed_at { Time.current }
    onboarding_step { 1 }

  end
end
