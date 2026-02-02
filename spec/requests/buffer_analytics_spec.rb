require 'rails_helper'

RSpec.describe "Buffer analytics", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /buffer_analytics" do
    it "returns http success" do
      get buffer_analytics_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /buffer_analytics/sync" do
    it "returns http success" do
      get sync_buffer_analytics_path
      expect(response).to be_success_with_view_check('sync')
    end
  end

end
