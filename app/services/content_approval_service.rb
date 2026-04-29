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
    user = draft.user
    app_name = Rails.application.config.x.appname
    post_now_url = Rails.application.routes.url_helpers.content_approval_url(token: draft.approval_token, action_type: "post_now", host: ENV.fetch("HOST", "ultimatesocialmedia01.com"), protocol: "https")
    schedule_url = Rails.application.routes.url_helpers.content_approval_url(token: draft.approval_token, action_type: "schedule", host: ENV.fetch("HOST", "ultimatesocialmedia01.com"), protocol: "https")
    reject_url = Rails.application.routes.url_helpers.content_approval_url(token: draft.approval_token, action_type: "reject", host: ENV.fetch("HOST", "ultimatesocialmedia01.com"), protocol: "https")

    platform_line = draft.platform.present? ? "<p style='margin:0 0 8px;color:#94a3b8;font-size:12px;font-weight:600;text-transform:uppercase;'>#{draft.platform.capitalize}</p>" : ""

    html_content = <<~HTML
      <!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"/></head>
      <body style="margin:0;padding:0;background:#f8fafc;font-family:'Helvetica Neue',Helvetica,Arial,sans-serif;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background:#f8fafc;padding:40px 0;">
          <tr><td align="center">
            <table width="580" cellpadding="0" cellspacing="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.07);">
              <tr><td style="background:linear-gradient(135deg,#1d4ed8,#7c3aed);padding:32px 40px;">
                <p style="margin:0;color:rgba(255,255,255,0.8);font-size:13px;letter-spacing:1px;text-transform:uppercase;">Content Review</p>
                <h1 style="margin:8px 0 0;color:#ffffff;font-size:24px;font-weight:700;">Your AI content is ready ✨</h1>
              </td></tr>
              <tr><td style="padding:36px 40px;">
                <p style="margin:0 0 8px;color:#64748b;font-size:14px;">Hi #{user.name || user.email},</p>
                <p style="margin:0 0 28px;color:#334155;font-size:15px;line-height:1.6;">Here's a preview of the AI-generated content queued for posting.</p>
                #{platform_line}
                <div style="background:#f1f5f9;border-left:4px solid #3b82f6;border-radius:0 8px 8px 0;padding:20px 24px;margin-bottom:32px;">
                  <p style="margin:0;color:#1e293b;font-size:16px;line-height:1.7;white-space:pre-wrap;">#{draft.content}</p>
                </div>
                <p style="margin:0 0 16px;color:#475569;font-size:14px;font-weight:600;">What would you like to do?</p>
                <table cellpadding="0" cellspacing="0" width="100%"><tr>
                  <td style="padding-right:8px;" width="50%"><a href="#{post_now_url}" style="display:block;text-align:center;background:#16a34a;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 20px;border-radius:8px;">Post Now</a></td>
                  <td style="padding-left:8px;" width="50%"><a href="#{schedule_url}" style="display:block;text-align:center;background:#2563eb;color:#ffffff;text-decoration:none;font-size:15px;font-weight:700;padding:14px 20px;border-radius:8px;">Schedule It</a></td>
                </tr></table>
                <p style="margin:24px 0 0;text-align:center;color:#94a3b8;font-size:13px;">Don't want to post this? <a href="#{reject_url}" style="color:#ef4444;text-decoration:none;font-weight:600;">Discard it</a></p>
              </td></tr>
              <tr><td style="background:#f8fafc;padding:20px 40px;border-top:1px solid #e2e8f0;">
                <p style="margin:0;color:#94a3b8;font-size:12px;text-align:center;line-height:1.6;">This link is unique to you and expires after use.</p>
              </td></tr>
            </table>
          </td></tr>
        </table>
      </body></html>
    HTML

    SendgridEmailService.send_email(
      to: user.email,
      subject: "[#{app_name}] Your AI content is ready for review ✍️",
      html_content: html_content
    )
  end
end
