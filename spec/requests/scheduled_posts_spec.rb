require 'rails_helper'

RSpec.describe "Scheduled posts", type: :request do

  # Uncomment this if controller need authentication
  let(:user) { last_or_create(:user) }
  before { sign_in_as(user) }

  describe "GET /scheduled_posts" do
    it "returns http success" do
      get scheduled_posts_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /scheduled_posts/:id" do
    let(:scheduled_post_record) { create(:scheduled_post, user: user) }

    it "returns http success" do
      get scheduled_post_path(scheduled_post_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /scheduled_posts/new" do
    it "returns http success" do
      get new_scheduled_post_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "GET /scheduled_posts/:id/edit" do
    let(:scheduled_post_record) { create(:scheduled_post, user: user) }

    it "returns http success" do
      get edit_scheduled_post_path(scheduled_post_record)
      expect(response).to be_success_with_view_check('edit')
    end
  end

  describe "POST /scheduled_posts" do
    it "creates a new scheduled_post" do
      content = create(:content, user: user)
      social_account = create(:social_account, user: user)
      post scheduled_posts_path, params: { 
        scheduled_post: { 
          content_id: content.id,
          social_account_id: social_account.id,
          scheduled_at: Time.current + 1.hour,
          status: 'scheduled'
        } 
      }
      expect(response).to be_success_with_view_check
    end
  end


  describe "PATCH /scheduled_posts/:id" do
    let(:scheduled_post_record) { create(:scheduled_post, user: user) }

    it "updates the scheduled_post" do
      patch scheduled_post_path(scheduled_post_record), params: { scheduled_post: attributes_for(:scheduled_post) }
      expect(response).to be_success_with_view_check
    end
  end
end
