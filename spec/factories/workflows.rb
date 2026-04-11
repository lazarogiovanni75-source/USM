FactoryBot.define do
  factory :workflow do
    association :user
    workflow_type { "content_to_post" }
    content { "Test workflow content" }
    title { "Test Workflow" }
    status { "pending" }
  end
end
