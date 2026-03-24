FactoryBot.define do
  factory :automation_rule do

    id { 1 }
    user_id { 1 }
    name { "MyString" }
    trigger_type { "MyString" }
    action_type { "MyString" }
    conditions { nil }
    actions { nil }
    is_active { true }

  end
end
