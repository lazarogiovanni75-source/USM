FactoryBot.define do
  factory :scheduled_post do

    association :content
    association :social_account
    scheduled_at { Time.current }
    status { "MyString" }
    posted_at { Time.current }
    platform_post_id { "MyString" }

  end
end
