FactoryBot.define do
  factory :scheduled_task do

    id { 1 }
    user_id { 1 }
    task_type { "MyString" }
    payload { nil }
    scheduled_at { Time.current }
    executed_at { Time.current }
    status { "MyString" }

  end
end
