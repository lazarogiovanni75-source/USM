FactoryBot.define do
  factory :campaign do
    name { "MyString" }
    description { "MyText" }
    association :user, factory: :user
    status { 3 } # running
    goal { "awareness" }
    campaign_type { "product_launch" }
    start_date { Date.current }
    end_date { Date.current + 30 }
  end
end
