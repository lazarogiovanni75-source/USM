# Content Validation Service
# Validates content for prohibited items and plan limits

class ContentValidationService
  PROHIBITED_PATTERNS = {
    illegal: /\b(illegal|criminal|fraud|piracy|hack|exploit)\b/i,
    explicit: /\b(sex|porn|nsfw|explicit|nude|adult)\b/i,
    hate: /\b(hate|racist|sexist|homophobic|discriminat)\b/i,
    harassment: /\b(bully|harass|threat|attack)\b/i,
    violence: /\b(kill|murder|attack|weapon|gun|knife|bomb)\b/i
  }.freeze

  def initialize(user = nil)
    @user = user
  end

  # Validate content and return errors
  def validate(content)
    errors = []

    # Check for prohibited content
    PROHIBITED_PATTERNS.each do |type, pattern|
      if content =~ pattern
        errors << prohibited_error_message(type)
      end
    end

    # Check content length limits
    if content.length > 5000
      errors << "Content exceeds maximum length of 5000 characters"
    end

    errors
  end

  # Quick check if content is prohibited
  def prohibited?(content)
    PROHIBITED_PATTERNS.any? { |_, pattern| content =~ pattern }
  end

  private

  def prohibited_error_message(type)
    case type
    when :illegal
      "Content contains references to illegal activities and cannot be processed"
    when :explicit
      "Content contains explicit material and cannot be processed"
    when :hate
      "Content contains hate speech and cannot be processed"
    when :harassment
      "Content contains harassment and cannot be processed"
    when :violence
      "Content contains violence and cannot be processed"
    else
      "Content violates our content policy"
    end
  end
end
