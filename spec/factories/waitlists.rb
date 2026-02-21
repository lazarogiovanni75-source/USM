FactoryBot.define do
  factory :waitlist do
    email { "test#{SecureRandom.hex(4)}@example.com" }
    status { true }
  end
end
