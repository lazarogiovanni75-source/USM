FactoryBot.define do
  factory :campaign do
    name { "MyString" }
    description { "MyText" }
    association :user, factory: :user
    status { "active" }
    goal { "MyString" }
    campaign_type { "general" }

  end
end
