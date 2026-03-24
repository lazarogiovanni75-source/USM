FactoryBot.define do
  factory :performance_metric do

    association :scheduled_post
    impressions { 1 }
    likes { 1 }
    comments { 1 }
    shares { 1 }
    engagement_rate { 9.99 }
    reach { 1 }

  end
end
