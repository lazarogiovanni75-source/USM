require 'rails_helper'

RSpec.describe "Social accounts", type: :request do

  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /social_accounts" do
    it "returns http success" do
      get social_accounts_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /social_accounts/:id" do
    let(:social_account_record) { create(:social_account, user: user) }

    it "returns http success" do
      get social_account_path(social_account_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /social_accounts/new" do
    it "returns http success" do
      get new_social_account_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /social_accounts/:id/edit" do
    let(:social_account_record) { create(:social_account, user: user) }

    it "returns http success" do
      get edit_social_account_path(social_account_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /social_accounts" do
    it "creates a new social_account" do
      post social_accounts_path, params: { social_account: attributes_for(:social_account) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /social_accounts/:id" do
    let(:social_account_record) { create(:social_account, user: user) }

    it "updates the social_account" do
      patch social_account_path(social_account_record), params: { social_account: attributes_for(:social_account) }
      expect(response).to be_success_with_view_check
    end
  end
end
