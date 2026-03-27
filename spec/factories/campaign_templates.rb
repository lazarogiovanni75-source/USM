FactoryBot.define do
  factory :campaign_template do

    name { "MyString" }
    description { "MyText" }
    duration_days { 1 }
    structure { nil }
    is_active { true }
    category { "MyString" }

  end
end
