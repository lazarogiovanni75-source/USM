require 'rails_helper'

RSpec.describe "Performance metrics", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /performance_metrics" do
    it "returns http success" do
      get performance_metrics_path
      expect(response).to be_success_with_view_check('index')
    end
  end
end
