

Please open app/controllers/api/v1/otto_controller.rb and find the system_prompt variable or method. Copy and paste the exact text content of the system prompt here in the chat — don't deploy anything, just show me what it says.
Also confirm: was tool_choice: { "type" => "any" } actually added to the Anthropic API call for image/video requests? Show me the exact lines of the chat_response method where the Anthropic client is called, including the tool_choice parameter.class Content < ApplicationRecord
  belongs_to :campaign, optional: true
  belongs_to :user

  has_many :scheduled_posts, dependent: :destroy

  serialize :media_urls, coder: JSON

  # Auto-sync media_url to media_urls for Postforme compatibility
  after_save :sync_media_url_to_media_urls

  scope :recent, -> { order(created_at: :desc) }
  scope :draft, -> { where(status: 'draft') }
  scope :published, -> { where(status: 'published') }

  def published?
    status == 'published'
  end

  private

  def sync_media_url_to_media_urls
    return unless media_url.present?
    return if media_urls.present? && media_urls.is_a?(Array) && media_urls.any?

    # Convert single media_url to media_urls array format
    update_column(:media_urls, [media_url]) if media_url.present?
  end
end
