require 'rails_helper'

RSpec.describe "Workflows", type: :request do

  # Uncomment this if controller need authentication
  # let(:user) { last_or_create(:user) }
  # before { sign_in_as(user) }

  describe "GET /workflows" do
    it "returns http success" do
      get workflows_path
      expect(response).to be_success_with_view_check('index')
    end
  end

  describe "GET /workflows/:id" do
    let(:workflow_record) { create(:workflow) }

    it "returns http success" do
      get workflow_path(workflow_record)
      expect(response).to be_success_with_view_check('show')
    end
  end

  describe "GET /workflows/new" do
    it "returns http success" do
      get new_workflow_path
      expect(response).to be_success_with_view_check('new')
    end
  end

  describe "POST /workflows" do
    it "creates a new workflow" do
      post workflows_path, params: { workflow: attributes_for(:workflow) }
      expect(response).to be_success_with_view_check
    end
  end
end
