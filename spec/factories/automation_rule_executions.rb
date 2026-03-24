FactoryBot.define do
  factory :automation_rule_execution do

    association :automation_rule
    trigger_data { nil }
    status { "MyString" }
    execution_details { nil }

  end
end
