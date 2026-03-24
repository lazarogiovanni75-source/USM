FactoryBot.define do
  factory :strategy_history do

    association :user
    focus_area { "MyString" }
    metrics { nil }
    strategy { nil }
    insights { nil }
    recommendations { "MyText" }
    kpis_tracked { nil }
    overall_score { 1 }
    generated_by { "MyString" }

  end
end
