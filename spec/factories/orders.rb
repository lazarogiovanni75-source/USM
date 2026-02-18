FactoryBot.define do
  factory :order do

    association :user
    total { 9.99 }
    status { 'pending' }

  end
end
