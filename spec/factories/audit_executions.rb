FactoryBot.define do
  factory :audit_execution do

    association :user
    tool_name { "MyString" }
    parameters { "MyText" }
    status { "MyString" }
    approved { true }
    executed_at { Time.current }
    session_id { "MyString" }

  end
end
