require 'rails_helper'

RSpec.describe "Contents", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /contents" do
    it "returns http success" do
      get contents_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /contents/:id" do
    let(:content_record) { create(:content, user: user) }

    it "returns http success" do
      get content_path(content_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /contents/new" do
    it "returns http success" do
      get new_content_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /contents/:id/edit" do
    let(:content_record) { create(:content, user: user) }

    it "returns http success" do
      get edit_content_path(content_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /contents" do
    it "creates a new content" do
      campaign = create(:campaign, user: user)
      post contents_path, params: { content: attributes_for(:content).merge(campaign_id: campaign.id) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /contents/:id" do
    let(:content_record) { create(:content, user: user) }

    it "updates the content" do
      patch content_path(content_record), params: { content: attributes_for(:content) }
      expect(response).to be_success_with_view_check
    end
  end
end
