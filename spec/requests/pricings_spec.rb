require 'rails_helper'

RSpec.describe "Pricings", type: :request do

  describe "GET /pricing" do
    it "returns http success" do
      get pages_pricing_path
      expect(response).to be_success_with_view_check('pricing')
    end
  end
end
