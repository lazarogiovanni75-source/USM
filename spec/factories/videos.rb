FactoryBot.define do
  factory :video do

    association :user
    title { "MyString" }
    description { "MyText" }
    status { "MyString" }
    video_type { "MyString" }
    duration { 1 }

  end
end
