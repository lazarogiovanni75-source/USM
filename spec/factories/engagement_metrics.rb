FactoryBot.define do
  factory :engagement_metric do

    id { 1 }
    content_id { 1 }
    metric_type { "MyString" }
    metric_value { 9.99 }
    date { Date.today }

  end
end
