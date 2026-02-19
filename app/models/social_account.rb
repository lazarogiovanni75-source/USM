class SocialAccount < ApplicationRecord
  belongs_to :user
  belongs_to :client, optional: true
  has_many :scheduled_posts, dependent: :destroy
  has_many :post_metrics, as: :post, dependent: :destroy

  # Encryption key from environment - must be 32 bytes
  def self.encryption_key
    key = Rails.application.credentials.secret_key_base || ENV.fetch('SOCIAL_ACCOUNTS_ENCRYPTION_KEY', 'default_dev_key_change_in_production')
    # Ensure key is exactly 32 bytes by hashing if needed
    if key.length < 32
      key.ljust(32, '0')
    else
      Digest::SHA256.hexdigest(key)[0..31]
    end
  end

  # Encrypt OAuth tokens before saving
  before_save :encrypt_oauth_tokens
  after_find :decrypt_oauth_tokens

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

  # ==================== OAuth Token Encryption ====================

  def access_token
    # Return decrypted token if available
    @decrypted_access_token || read_attribute(:access_token)
  end

  def access_token=(value)
    @new_access_token = value
    write_attribute(:access_token, value)
  end

  def refresh_token
    @decrypted_refresh_token || read_attribute(:refresh_token)
  end

  def refresh_token=(value)
    @new_refresh_token = value
    write_attribute(:refresh_token, value)
  end

  def expires_at
    read_attribute(:oauth_expires_at)
  end

  def expires_at=(value)
    write_attribute(:oauth_expires_at, value)
  end

  def token_expired?
    return false unless expires_at.present?
    expires_at < Time.current
  end

  def needs_refresh?
    token_expired? && refresh_token.present?
  end

  private

  def encrypt_oauth_tokens
    # Encrypt oauth_access_token
    if @new_access_token.present?
      encrypted = encrypt(@new_access_token)
      write_attribute(:access_token, encrypted)
      @decrypted_access_token = @new_access_token
    end
    
    # Encrypt oauth_refresh_token
    if @new_refresh_token.present?
      encrypted = encrypt(@new_refresh_token)
      write_attribute(:refresh_token, encrypted)
      @decrypted_refresh_token = @new_refresh_token
    end
  end

  def decrypt_oauth_tokens
    return unless persisted?
    
    if read_attribute(:access_token).present?
      @decrypted_access_token = decrypt(read_attribute(:access_token))
    end
    
    if read_attribute(:refresh_token).present?
      @decrypted_refresh_token = decrypt(read_attribute(:refresh_token))
    end
  rescue StandardError => e
    Rails.logger.warn "[SocialAccount] Failed to decrypt tokens: #{e.message}"
  end

  def encrypt(text)
    return nil unless text.present?
    
    crypt = ActiveSupport::MessageEncryptor.new(self.class.encryption_key)
    crypt.encrypt_and_sign(text)
  end

  def decrypt(encrypted_text)
    return nil unless encrypted_text.present?
    
    crypt = ActiveSupport::MessageEncryptor.new(self.class.encryption_key)
    crypt.decrypt_and_verify(encrypted_text)
  rescue ActiveSupport::MessageEncryptor::InvalidMessage
    # Return as-is if decryption fails (might be plaintext from before encryption)
    encrypted_text
  end
end
