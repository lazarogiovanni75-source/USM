require 'rails_helper'

RSpec.describe "Voice commands", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /voice_commands" do
    it "returns http success" do
      get voice_commands_path
      expect(response).to be_success_with_view_check('index')
    end
  end
end
