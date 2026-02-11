class SocialAccount < ApplicationRecord
  belongs_to :user

  # Alias for account_name to provide a name method
  alias_attribute :name, :account_name

  # No username column - use account_name as fallback
  alias_attribute :username, :account_name

  # Postforme integration fields
  validates :postforme_profile_id, presence: true, if: -> { postforme_api_key.present? }
  validates :postforme_api_key, presence: true, if: -> { postforme_profile_id.present? }

  # Platform-specific profile IDs mapping
  PLATFORM_POSTFORME_PROFILES = {
    'twitter' => :twitter_profile_id,
    'facebook' => :facebook_profile_id,
    'instagram' => :instagram_profile_id,
    'linkedin' => :linkedin_profile_id
  }.freeze

  def postforme_profile_id_for_platform
    return nil unless postforme_profile_id.present?

    postforme_profile_id
  end

  def postforme_api_key_for_platform
    return nil unless postforme_api_key.present?

    postforme_api_key
  end

  def configured_for_postforme?
    postforme_profile_id.present? && postforme_api_key.present?
  end

  # Deprecated Buffer methods (kept for backward compatibility during migration)
  def buffer_profile_id_for_platform
    return nil unless buffer_profile_id.present?

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
