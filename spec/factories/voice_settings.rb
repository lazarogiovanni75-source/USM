FactoryBot.define do
  factory :voice_setting do

    id { 1 }
    user_id { 1 }
    voice_id { "MyString" }
    tone { "MyString" }
    speed { 9.99 }

  end
end
