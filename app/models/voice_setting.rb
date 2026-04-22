class VoiceSetting < ApplicationRecord
  belongs_to :user
  
  validates :voice_id, presence: true
  validates :tone, presence: true
  validates :speed, numericality: { greater_than: 0, less_than_or_equal_to: 3.0 }

  # Safe TTS check - returns false if column doesn't exist
  def tts_enabled?
    return false unless respond_to?(:tts_enabled)
    tts_enabled == true
  end

  # Safe language accessor - returns default if column doesn't exist
  def tts_language
    return 'en' unless respond_to?(:language)
    language.presence || 'en'
  end

  # Voice mode: 'auto' (auto-send on silence) or 'manual' (press again to send)
  def voice_mode
    return 'auto' unless respond_to?(:voice_mode)
    voice_mode.presence || 'auto'
  end

  def auto_mode?
    voice_mode == 'auto'
  end

  def manual_mode?
    voice_mode == 'manual'
  end
end