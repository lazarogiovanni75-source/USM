# frozen_string_literal: true

class SendgridEmailService
  class EmailDeliveryError < StandardError; end

  SENDGRID_API_URL = "https://api.sendgrid.com/v3/mail/send".freeze

  def self.send_email(to:, subject:, html_content:, from_email: nil, from_name: nil)
    api_key = ENV["SENDGRID_API_KEY"]
    raise EmailDeliveryError, "SENDGRID_API_KEY not configured" if api_key.blank?

    from_email ||= ENV.fetch("SENDGRID_FROM_EMAIL", "noreply@ultimatesocialmedia01.com")
    from_name  ||= ENV.fetch("SENDGRID_FROM_NAME", "Social Media Automation")

    payload = {
      personalizations: [
        {
          to: [{ email: to.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "") }]
        }
      ],
      from: {
        email: from_email.to_s,
        name:  from_name.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      },
      subject: subject.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: ""),
      content: [
        {
          type:  "text/html",
          value: html_content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
        }
      ]
    }

    response = HTTParty.post(
      SENDGRID_API_URL,
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type"  => "application/json"
      },
      body: payload.to_json
    )

    status = response.code.to_i

    unless status >= 200 && status < 300
      # Read the raw body without JSON parsing to avoid control character errors
      raw_body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      raise EmailDeliveryError, "SendGrid API error: #{status} - #{raw_body}"
    end

    { success: true, status: status }
  rescue EmailDeliveryError
    raise
  rescue StandardError => e
    raise EmailDeliveryError, "SendGrid delivery failed: #{e.message}"
  end
end
