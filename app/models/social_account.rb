class SocialAccount < ApplicationRecord
  belongs_to :user

  # Buffer integration fields
  validates :buffer_profile_id, presence: true, if: -> { buffer_access_token.present? }
  validates :buffer_access_token, presence: true, if: -> { buffer_profile_id.present? }

  # Platform-specific profile IDs mapping
  PLATFORM_BUFFER_PROFILES = {
    'twitter' => :twitter_profile_id,
    'facebook' => :facebook_profile_id,
    'instagram' => :instagram_profile_id,
    'linkedin' => :linkedin_profile_id
  }.freeze

  def buffer_profile_id_for_platform
    return nil unless buffer_profile_id.present?

    # If buffer_profile_id is already set for this account, use it
    buffer_profile_id
  end

  def buffer_access_token_for_platform
    return nil unless buffer_access_token.present?

    buffer_access_token
  end

  def configured_for_buffer?
    buffer_profile_id.present? && buffer_access_token.present?
  end
end
