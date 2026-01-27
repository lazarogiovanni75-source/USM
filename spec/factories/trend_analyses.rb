FactoryBot.define do
  factory :trend_analysis do

    id { 1 }
    user_id { 1 }
    analysis_type { "MyString" }
    data { nil }
    trend_score { 9.99 }
    insights { "MyText" }

  end
end
