require 'rails_helper'

RSpec.describe ScheduledPost, type: :model do
  let(:user) { create(:user) }
  let(:content) { create(:content, user: user) }
  let(:social_account) { create(:social_account, user: user, platform: 'instagram') }
  
  describe 'status enum' do
    it 'defines draft, scheduled, published, failed, cancelled statuses' do
      expect(ScheduledPost.statuses.keys).to include('draft', 'scheduled', 'published', 'failed', 'cancelled')
    end
  end
  
  describe 'scopes' do
    let!(:draft_post) { create(:scheduled_post, user: user, status: :draft, scheduled_at: 1.hour.ago) }
    let!(:scheduled_post) { create(:scheduled_post, user: user, status: :scheduled, scheduled_at: 1.hour.ago) }
    let!(:future_post) { create(:scheduled_post, user: user, status: :scheduled, scheduled_at: 1.day.from_now) }
    let!(:published_post) { create(:scheduled_post, user: user, status: :published, scheduled_at: 1.day.ago) }
    let!(:failed_post) { create(:scheduled_post, user: user, status: :failed, scheduled_at: 1.hour.ago) }
    
    describe '.due' do
      it 'returns posts that are due to be published' do
        due_posts = ScheduledPost.due
        expect(due_posts).to include(scheduled_post)
        expect(due_posts).to include(draft_post)
        expect(due_posts).not_to include(published_post)
        expect(due_posts).not_to include(future_post)
      end
    end
    
    describe '.by_status' do
      it 'filters by status' do
        expect(ScheduledPost.by_status('draft')).to include(draft_post)
        expect(ScheduledPost.by_status('scheduled')).not_to include(draft_post)
      end
    end
    
    describe '.for_date' do
      it 'filters by date' do
        date = scheduled_post.scheduled_at.to_date
        expect(ScheduledPost.for_date(date)).to include(scheduled_post)
      end
    end
  end
  
  describe '#all_platforms' do
    context 'with single platform' do
      let(:post) { create(:scheduled_post, user: user, social_account: social_account, target_platforms: nil) }
      
      it 'returns single platform as array' do
        expect(post.all_platforms).to eq(['instagram'])
      end
    end
    
    context 'with target_platforms' do
      let(:post) { create(:scheduled_post, user: user, social_account: nil, target_platforms: %w[instagram twitter linkedin]) }
      
      it 'returns target platforms array' do
        expect(post.all_platforms).to eq(%w[instagram twitter linkedin])
      end
    end
  end
  
  describe '#can_edit?' do
    let(:post) { create(:scheduled_post, user: user, status: :scheduled, scheduled_at: 1.day.from_now) }
    
    context 'when scheduled and in future' do
      it 'returns true' do
        expect(post.can_edit?).to be true
      end
    end
    
    context 'when in past' do
      before { post.update(scheduled_at: 1.day.ago) }
      
      it 'returns false' do
        expect(post.can_edit?).to be false
      end
    end
    
    context 'when published' do
      before { post.update(status: :published) }
      
      it 'returns false' do
        expect(post.can_edit?).to be false
      end
    end
  end
  
  describe '#can_cancel?' do
    let(:post) { create(:scheduled_post, user: user, status: :scheduled, scheduled_at: 1.day.from_now) }
    
    context 'when scheduled' do
      it 'returns true' do
        expect(post.can_cancel?).to be true
      end
    end
    
    context 'when draft' do
      before { post.update(status: :draft) }
      
      it 'returns true' do
        expect(post.can_cancel?).to be true
      end
    end
    
    context 'when published' do
      before { post.update(status: :published) }
      
      it 'returns false' do
        expect(post.can_cancel?).to be false
      end
    end
  end
  
  describe '#has_assets?' do
    context 'with content media_url' do
      let(:content_with_media) { create(:content, user: user, media_url: 'https://example.com/image.jpg') }
      let(:post) { create(:scheduled_post, content: content_with_media) }
      
      it 'returns true' do
        expect(post.has_assets?).to be true
      end
    end
    
    context 'with image_url on post' do
      let(:post) { create(:scheduled_post, user: user, image_url: 'https://example.com/image.jpg') }
      
      it 'returns true' do
        expect(post.has_assets?).to be true
      end
    end
    
    context 'without any assets' do
      let(:post) { create(:scheduled_post, user: user) }
      
      it 'returns false' do
        expect(post.has_assets?).to be false
      end
    end
  end
  
  describe '#ready_to_publish?' do
    let(:post) { create(:scheduled_post, user: user, status: :scheduled, scheduled_at: 1.day.from_now) }
    
    context 'when all conditions met' do
      before do
        post.update(scheduled_at: 1.day.ago, image_url: 'https://example.com/image.jpg')
      end
      
      it 'returns true' do
        expect(post.ready_to_publish?).to be true
      end
    end
    
    context 'when scheduled_at is in future' do
      before do
        post.update(scheduled_at: 1.day.from_now, image_url: 'https://example.com/image.jpg')
      end
      
      it 'returns false' do
        expect(post.ready_to_publish?).to be false
      end
    end
    
    context 'when status is published' do
      before do
        post.update(status: :published)
      end
      
      it 'returns false' do
        expect(post.ready_to_publish?).to be false
      end
    end
  end
  
  describe 'validations' do
    describe 'scheduled_at' do
      it 'is required' do
        post = build(:scheduled_post, user: user, scheduled_at: nil)
        expect(post).not_to be_valid
        expect(post.errors[:scheduled_at]).to include("can't be blank")
      end
    end
    
    describe '#validate_target_platforms' do
      context 'with valid platforms' do
        let(:post) { build(:scheduled_post, target_platforms: %w[instagram twitter]) }
        
        it 'is valid' do
          expect(post).to be_valid
        end
      end
      
      context 'with invalid platforms' do
        let(:post) { build(:scheduled_post, target_platforms: %w[instagram invalid_platform]) }
        
        it 'is invalid' do
          expect(post).not_to be_valid
          expect(post.errors[:target_platforms]).to include(/contains invalid platforms/)
        end
      end
    end
  end
  
  # Factory test
  it 'can be created with factory' do
    post = create(:scheduled_post, user: user, content: content, social_account: social_account)
    expect(post).to be_persisted
    expect(post.status).to eq('scheduled')
  end
end
