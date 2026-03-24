FactoryBot.define do
  factory :ai_message do

    id { 1 }
    conversation_id { 1 }
    role { "MyString" }
    content { "MyText" }
    tokens_used { 1 }

  end
end
