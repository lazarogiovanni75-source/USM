FactoryBot.define do
  factory :voice_command do

    association :user
    command { "MyText" }
    transcribed_text { "MyText" }
    status { "MyString" }
    response_text { "MyText" }
    campaign_id { 1 }
    ai_confidence { 9.99 }

  end
end
