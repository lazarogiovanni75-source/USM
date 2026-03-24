class ApplicationMailer < ActionMailer::Base
  default from: "#{(Rails.application.config.x.appname.presence || 'Ultimate Social Media')} <notifications@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}>"
  layout "mailer"
end
