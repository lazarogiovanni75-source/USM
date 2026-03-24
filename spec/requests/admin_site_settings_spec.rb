require 'rails_helper'

RSpec.describe "Admin::SiteSettings", type: :request do
  before { admin_sign_in_as(create(:administrator)) }

  describe "GET /admin/site_settings" do
    it "returns http success" do
      get admin_site_settings_path
      expect(response).to be_success_with_view_check('index')
    end
  end

end
