require 'rails_helper'

RSpec.describe "Waitlists", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /waitlists" do
    it "returns http success" do
      get waitlists_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /waitlists/:id" do
    let(:waitlist_record) { create(:waitlist_email) }

    it "returns http success" do
      get waitlist_path(waitlist_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /waitlists/new" do
    it "returns http success" do
      get new_waitlist_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /waitlists/:id/edit" do
    let(:waitlist_record) { create(:waitlist_email) }

    it "returns http success" do
      get edit_waitlist_path(waitlist_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /waitlists" do
    it "creates a new waitlist" do
      post waitlists_path, params: { waitlist: attributes_for(:waitlist_email) }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /waitlists/:id" do
    let(:waitlist_record) { create(:waitlist_email) }

    it "updates the waitlist" do
      patch waitlist_path(waitlist_record), params: { waitlist: attributes_for(:waitlist_email) }
      expect(response).to be_success_with_view_check
    end
  end
end
