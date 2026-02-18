FactoryBot.define do
  factory :user_subscription do

    association :user
    association :subscription_plan
    status { 'pending' }
    started_at { Time.current }
    expires_at { Time.current }
    credits_used { 1 }
    stripe_subscription_id { "MyString" }

  end
end
