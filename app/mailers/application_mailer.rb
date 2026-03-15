class ApplicationMailer < ActionMailer::Base
  default from: "#{(Rails.application.config.x.appname.presence || 'Vyropilot')} <notifications@#{ENV.fetch("EMAIL_SMTP_DOMAIN", 'example.com')}>"
  layout "mailer"
end
