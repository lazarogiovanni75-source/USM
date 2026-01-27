FactoryBot.define do
  factory :draft_content do

    id { 1 }
    user_id { 1 }
    title { "MyString" }
    content { "MyText" }
    content_type { "MyString" }
    platform { "MyString" }
    status { "MyString" }

  end
end
