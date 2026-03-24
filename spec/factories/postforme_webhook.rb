FactoryBot.define do
  factory :postforme_webhook do
    event_type { "post.published" }
    payload { { "post" => { "id" => "12345", "title" => "Test Post" } } }
    status { "pending" }
    processed_at { nil }
  end
end
