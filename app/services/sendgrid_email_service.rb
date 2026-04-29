# frozen_string_literal: true

class SendgridEmailService
  class EmailDeliveryError < StandardError; end

  def self.send_email(to:, subject:, html_content:, from_email: nil, from_name: nil)
    api_key = ENV["SENDGRID_API_KEY"]
    raise EmailDeliveryError, "SENDGRID_API_KEY not configured" if api_key.blank?

    from_email ||= ENV.fetch("SENDGRID_FROM_EMAIL", "noreply@ultimatesocialmedia01.com")
    from_name ||= ENV.fetch("SENDGRID_FROM_NAME", "Social Media Automation")

    sg = SendGrid::API.new(api_key: api_key)

    from = SendGrid::From.new(email: from_email, name: from_name)
    to = SendGrid::To.new(email: to)
    subject = SendGrid::Subject.new(subject)
    html_content = SendGrid::HtmlContent.new(html: html_content)

    mail = SendGrid::Mail.new(from, subject, to, html_content)

    response = sg.client.mail._("send").post(request_body: mail.to_json)

    unless response.status_code.to_i >= 200 && response.status_code.to_i < 300
      raise EmailDeliveryError, "SendGrid API error: #{response.status_code} - #{response.body}"
    end

    { success: true, status: response.status_code }
  rescue JSON::ParserError => e
    raise EmailDeliveryError, "SendGrid API response parse error: #{e.message}"
  rescue StandardError => e
    raise EmailDeliveryError, "SendGrid delivery failed: #{e.message}"
  end
end
