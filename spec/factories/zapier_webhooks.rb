FactoryBot.define do
  factory :zapier_webhook do

    id { 1 }
    user_id { 1 }
    webhook_url { "MyString" }
    event_type { "MyString" }
    is_active { true }

  end
end
