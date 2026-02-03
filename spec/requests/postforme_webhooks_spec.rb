require 'rails_helper'

RSpec.describe "Postforme webhooks", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "POST /postforme_webhooks" do
    it "creates a new postforme_webhook" do
      post postforme_webhooks_path, params: { postforme_webhook: attributes_for(:postforme_webhook) }
      expect(response).to be_success_with_view_check
    end
  end
end
