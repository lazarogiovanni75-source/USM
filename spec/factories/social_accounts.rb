FactoryBot.define do
  factory :social_account do

    association :user
    platform { "MyString" }
    account_name { "MyString" }
    account_url { "MyString" }
    access_token { "MyString" }
    is_connected { true }

  end
end
