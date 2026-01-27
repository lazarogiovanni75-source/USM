FactoryBot.define do
  factory :content_suggestion do

    id { 1 }
    user_id { 1 }
    content_type { "MyString" }
    topic { "MyText" }
    suggestion { "MyText" }
    confidence { 9.99 }
    status { "MyString" }

  end
end
