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
    app_name = Rails.application.config.x.appname
    user = draft.user
    post_now_url = content_approval_url(token: draft.approval_token, action_type: "post_now")
    schedule_url = content_approval_url(token: draft.approval_token, action_type: "schedule")
    reject_url = content_approval_url(token: draft.approval_token, action_type: "reject")

    html_content = <<~HTML
      <div style="font-family:sans-serif;max-width:560px;margin:0 auto;padding:40px;">
        <h1 style="font-size:24px;font-weight:700;">Your AI Content is Ready! ✍️</h1>
        <p>Your #{draft.content_type} for <strong>#{draft.platform}</strong> has been created:</p>
        <blockquote style="border-left:4px solid #2563eb;padding-left:16px;margin:16px 0;">
          #{draft.content.truncate(200)}
        </blockquote>
        <p><a href="#{post_now_url}" style="background:#16a34a;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Post Now</a></p>
        <p><a href="#{schedule_url}" style="background:#2563eb;color:#fff;padding:12px 24px;text-decoration:none;border-radius:6px;display:inline-block;">Schedule</a></p>
        <p><a href="#{reject_url}" style="color:#dc2626;">Reject</a></p>
      </div>
    HTML

    SendgridEmailService.send_email(
      to: user.email,
      subject: "[#{app_name}] Your AI content is ready for review ✍️",
      html_content: html_content
    )
  end
end
