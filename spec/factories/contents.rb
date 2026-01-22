FactoryBot.define do
  factory :content do
    association :campaign, factory: :campaign
    association :user, factory: :user
    title { "MyString" }
    body { "MyText" }
    content_type { "post" }
    platform { "instagram" }
    media_urls { [] }
    status { "draft" }
    engagement_metrics { {} }

  end
end
