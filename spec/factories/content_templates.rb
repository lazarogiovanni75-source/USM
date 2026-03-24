FactoryBot.define do
  factory :content_template do

    id { 1 }
    name { "MyString" }
    category { "MyString" }
    content { "MyText" }
    variables { nil }
    platform { "MyString" }
    is_active { true }

  end
end
