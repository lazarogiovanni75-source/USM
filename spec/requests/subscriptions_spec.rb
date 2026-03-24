require 'rails_helper'

RSpec.describe "Subscriptions", type: :request do

  let(:user) { last_or_create(:user) }
  let(:plan) { SubscriptionPlan.create!(name: "Test Plan", price_cents: 2900, credits: 10, description: "Test", features: "Test", is_popular: false) }
  
  before { sign_in_as(user) }

  describe "POST /subscriptions" do
    it "creates a new subscription" do
      post subscriptions_path, params: { plan_id: plan.id }
      expect(response).to redirect_to(match(/\/payments\/\d+\/pay/))
    end
  end
end
