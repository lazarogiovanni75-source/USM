require 'rails_helper'

RSpec.describe "Postforme webhooks", type: :request do

  describe "POST /api/v1/postforme/webhook" do
    it "receives webhook and processes data" do
      payload = {
        event: "post.published",
        post: {
          id: "12345",
          title: "Test Post"
        }
      }.to_json

      post api_v1_postforme_webhook_path, params: payload, headers: { 'Content-Type' => 'application/json' }
      expect(response).to have_http_status(:ok)
    end
  end
end
