FactoryBot.define do
  factory :prompt_template do

    id { 1 }
    name { "MyString" }
    category { "MyString" }
    prompt { "MyText" }
    description { "MyText" }
    variables { nil }
    is_public { true }

  end
end
