FactoryBot.define do
  factory :buffer_analytic do

    association :scheduled_post
    buffer_update_id { "MyString" }
    clicks { 1 }
    impressions { 1 }
    engagement { 1 }
    reach { 1 }
    shares { 1 }
    likes { 1 }
    comments { 1 }
    posted_at { Time.current }
    synced_at { Time.current }

  end
end
