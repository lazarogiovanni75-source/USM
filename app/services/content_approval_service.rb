class ContentApprovalService < ApplicationService
  def initialize(user:, content:, platform: nil, content_type: 'post')
    @user = user
    @content = content
    @platform = platform.presence || 'general'
    @content_type = content_type
  end

  def call
    # Create draft content with pending status
    draft = DraftContent.create!(
      user: @user,
      title: generate_title,
      content: @content,
      platform: @platform,
      content_type: @content_type,
      status: 'pending'
    )
    
    # Send approval email
    send_approval_email(draft)
    
    { success: true, draft: draft }
  end

  private

  def generate_title
    "#{@content_type.titleize} - #{Time.current.strftime('%Y-%m-%d %H:%M')}"
  end

  def send_approval_email(draft)
    ContentMailer.approval_email(draft).deliver_later
  end
end
