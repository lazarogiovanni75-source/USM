class ContentMailer < ApplicationMailer
  def approval_email(draft)
    @draft = draft
    @user = draft.user
    
    @post_now_url = content_approval_url(token: draft.approval_token, action_type: "post_now")
    @schedule_url = content_approval_url(token: draft.approval_token, action_type: "schedule")
    @reject_url = content_approval_url(token: draft.approval_token, action_type: "reject")
    
    mail(
      to: @user.email,
      subject: "[#{Rails.application.config.x.appname}] Your AI content is ready for review ✍️"
    )
  end
end
