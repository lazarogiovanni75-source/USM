FactoryBot.define do
  factory :waitlist do
    email { "test#{SecureRandom.hex(4)}@example.com" }
    status { true }
  end

  factory :waitlist_email, class: 'WaitlistEmail' do
    email { "test#{SecureRandom.hex(4)}@example.com" }
    status { 'pending' }
  end
end
