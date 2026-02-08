# frozen_string_literal: true

class SoraPollJob < ApplicationJob
  queue_as :default

  MAX_ATTEMPTS = 60 # Poll for up to 5 minutes (60 * 5 seconds)
  POLL_INTERVAL = 5.seconds

  def perform(draft_id, prediction_url, attempt = 0)
    draft = DraftContent.find(draft_id)

    return if draft.media_url.present?

    if attempt >= MAX_ATTEMPTS
      draft.update(status: 'failed')
      Rails.logger.error "SoraPollJob: Max attempts reached for draft #{draft_id}"
      return
    end

    response = fetch_prediction_status(prediction_url)

    case response['status']
    when 'succeeded'
      if response['output'].present?
        draft.update(
          media_url: response['output'],
          status: 'draft'
        )
        Rails.logger.info "SoraPollJob: Draft #{draft_id} completed successfully"
      else
        draft.update(status: 'failed')
        Rails.logger.error "SoraPollJob: Draft #{draft_id} succeeded but no output"
      end
    when 'failed'
      draft.update(status: 'failed')
      Rails.logger.error "SoraPollJob: Draft #{draft_id} failed - #{response['error']}"
    when 'processing', 'starting'
      # Still processing, schedule next poll
      SoraPollJob.perform_later(draft_id, prediction_url, attempt + 1)
    else
      # Unknown status, schedule next poll
      SoraPollJob.perform_later(draft_id, prediction_url, attempt + 1)
    end
  end

  private

  def fetch_prediction_status(prediction_url)
    uri = URI.parse(prediction_url)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Token #{ENV.fetch('REPLICATE_API_TOKEN', nil)}"
    request['Accept'] = 'application/json'

    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.request(request)
  end
end
