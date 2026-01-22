require 'rails_helper'

RSpec.describe "Campaigns", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /campaigns" do
    it "returns http success" do
      get campaigns_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /campaigns/:id" do
    let(:campaign_record) { create(:campaign, user: user) }

    it "returns http success" do
      get campaign_path(campaign_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /campaigns/new" do
    it "returns http success" do
      get new_campaign_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /campaigns/:id/edit" do
    let(:campaign_record) { create(:campaign, user: user) }

    it "returns http success" do
      get edit_campaign_path(campaign_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /campaigns" do
    it "creates a new campaign" do
      post campaigns_path, params: { campaign: attributes_for(:campaign) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /campaigns/:id" do
    let(:campaign_record) { create(:campaign, user: user) }

    it "updates the campaign" do
      patch campaign_path(campaign_record), params: { campaign: attributes_for(:campaign) }
      expect(response).to be_success_with_view_check
    end
  end
end
