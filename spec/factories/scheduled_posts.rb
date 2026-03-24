FactoryBot.define do
  factory :scheduled_post do
    association :content, factory: :content
    association :social_account, factory: :social_account
    association :user, factory: :user
    scheduled_at { 1.day.from_now }
    status { "scheduled" }
    posted_at { nil }
    platform_post_id { nil }
    target_platforms { nil }
    image_url { nil }
    video_url { nil }
    asset_url { nil }
  end
end
