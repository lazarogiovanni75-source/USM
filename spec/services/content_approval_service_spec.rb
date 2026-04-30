require 'rails_helper'

RSpec.describe ContentApprovalService, type: :service do
  describe '#call' do
    let(:user) { create(:user) }
    let(:content) { "This is a test post content" }
    
    it 'creates a draft and sends approval email' do
      service = ContentApprovalService.new(user: user, content: content)
      result = service.call
      
      expect(result[:success]).to be true
      expect(result[:draft]).to be_a(DraftContent)
      expect(result[:draft].status).to eq('pending')
      expect(result[:draft].approval_token]).to be_present
      expect(result[:draft].content).to eq(content)
    end
    
    it 'generates a title for the draft' do
      service = ContentApprovalService.new(user: user, content: content, platform: 'twitter')
      result = service.call
      
      expect(result[:draft].title).to include('Post')
    end
    
    it 'sets platform if provided' do
      service = ContentApprovalService.new(user: user, content: content, platform: 'instagram')
      result = service.call
      
      expect(result[:draft].platform).to eq('instagram')
    end
  end
end