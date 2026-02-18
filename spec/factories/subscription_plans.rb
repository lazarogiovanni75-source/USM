FactoryBot.define do
  factory :subscription_plan do

    name { "MyString" }
    price_cents { 1 }
    credits { 1 }
    description { "MyText" }
    features { "MyText" }
    is_popular { true }

  end
end
