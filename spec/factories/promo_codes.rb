FactoryBot.define do
  factory :promo_code do
    code { "MyString" }
    discount_percent { 1 }
    discount_amount { 1 }
    is_active { true }
    expires_at { Time.current }
    max_uses { 1 }
    use_count { 1 }
  end
end
