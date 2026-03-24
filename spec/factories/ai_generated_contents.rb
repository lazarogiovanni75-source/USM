FactoryBot.define do
  factory :ai_generated_content do

    topic { "MyString" }
    brand_voice { "MyString" }
    platform { "MyString" }
    content_type { "MyString" }
    caption { "MyText" }
    blog_post { "MyText" }
    ad_copy { "MyText" }
    hashtags { "MyText" }
    thread_story { "MyText" }
    email_marketing { "MyText" }
    additional_context { "MyText" }
    association :user

  end
end
