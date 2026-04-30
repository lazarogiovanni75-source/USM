# frozen_string_literal: true

class ResendEmailService
  class EmailDeliveryError < StandardError; end

  RESEND_API_URL = "https://api.resend.com/emails".freeze

  def self.send_email(to:, subject:, html_content:, from_email: nil, from_name: nil)
    api_key = ENV["RESEND_API_KEY"]
    raise EmailDeliveryError, "RESEND_API_KEY not configured" if api_key.blank?

    from_email ||= ENV.fetch("RESEND_FROM_EMAIL", "onboarding@resend.dev")
    from_name  ||= ENV.fetch("RESEND_FROM_NAME", "Social Media Automation")

    # Resend requires "From" header in format "Name <email@domain.com>"
    from_header = from_name.present? ? "#{from_name} <#{from_email}>" : from_email

    payload = {
      from: from_header,
      to: [to.to_s],
      subject: subject.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: ""),
      html: html_content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
    }

    response = HTTParty.post(
      RESEND_API_URL,
      headers: {
        "Authorization" => "Bearer #{api_key}",
        "Content-Type"  => "application/json"
      },
      body: payload.to_json
    )

    status = response.code.to_i

    unless status >= 200 && status < 300
      raw_body = response.body.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "")
      raise EmailDeliveryError, "Resend API error: #{status} - #{raw_body}"
    end

    { success: true, status: status }
  rescue EmailDeliveryError
    raise
  rescue StandardError => e
    raise EmailDeliveryError, "Resend delivery failed: #{e.message}"
  end
end
