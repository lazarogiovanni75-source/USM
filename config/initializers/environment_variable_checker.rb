# Environment Variable Checker - Logs all required API keys on startup
# This initializer runs in ALL environments and logs the status of critical environment variables

Rails.application.config.after_initialize do
  Rails.logger.info "=" * 60
  Rails.logger.info "ENVIRONMENT VARIABLE STATUS CHECK"
  Rails.logger.info "Environment: #{Rails.env}"
  Rails.logger.info "=" * 60

  # Define all required environment variables to check
  required_vars = {
    'ANTHROPIC_API_KEY' => 'Anthropic Claude API',
    'ATLASCLOUD_API_KEY' => 'Atlas Cloud API',
    'CLACKY_OPENAI_API_KEY' => 'OpenAI API (Whisper/TTS)',
  }

  optional_vars = {
    'ANTHROPIC_MODEL' => 'Anthropic Model',
    'ATLASCLOUD_BASE_URL' => 'Atlas Cloud Base URL',
  }

  Rails.logger.info "\n--- REQUIRED API KEYS ---"
  required_vars.each do |var, description|
    value = ENV[var]
    if value.present?
      masked = value.slice(0, 8) + "..." + "[#{value.length} chars]"
      Rails.logger.info "✅ #{var}: PRESENT (#{masked}) - #{description}"
    else
      # Also check alternate environment variable names
      alternate = case var
                  when 'ANTHROPIC_API_KEY' then ENV['CLACKY_ANTHROPIC_API_KEY']
                  when 'ATLASCLOUD_API_KEY' then ENV['ATLAS_CLOUD_API_KEY']
                  else nil
                  end
      
      if alternate.present?
        masked = alternate.slice(0, 8) + "..." + "[#{alternate.length} chars]"
        Rails.logger.info "✅ #{var} (via alternate): PRESENT (#{masked}) - #{description}"
      else
        Rails.logger.warn "❌ #{var}: MISSING or EMPTY - #{description}"
      end
    end
  end

  Rails.logger.info "\n--- OPTIONAL CONFIGURATION ---"
  optional_vars.each do |var, description|
    value = ENV[var]
    if value.present?
      Rails.logger.info "✅ #{var}: #{value} - #{description}"
    else
      Rails.logger.info "⚪ #{var}: NOT SET (will use default) - #{description}"
    end
  end

  Rails.logger.info "\n--- LOADED .ENV FILE? ---"
  env_file = Rails.root.join('.env')
  if File.exist?(env_file)
    # Read and parse the .env file to show what's in it
    env_content = File.read(env_file)
    if env_content.include?('ANTHROPIC_API_KEY=') || env_content.include?('ATLASCLOUD_API_KEY=')
      # Show line count of .env file
      line_count = env_content.lines.count
      size_bytes = env_content.bytesize
      Rails.logger.warn "⚠️  .env file exists (#{line_count} lines, #{size_bytes} bytes)"
      
      # Check for empty API keys
      empty_keys = []
      env_content.lines.each do |line|
        if line =~ /^ANTHROPIC_API_KEY=$/ || line =~ /^ATLASCLOUD_API_KEY=$/
          empty_keys << line.split('=').first.strip
        end
      end
      
      if empty_keys.any?
        Rails.logger.error "❌ .env file contains EMPTY API keys: #{empty_keys.join(', ')}"
        Rails.logger.error "   This may OVERRIDE Railway environment variables!"
      end
    else
      Rails.logger.info "✅ .env file exists but contains no API keys (safe)"
    end
  else
    Rails.logger.info "ℹ️  .env file does not exist"
  end

  Rails.logger.info "=" * 60
  Rails.logger.info "END OF ENVIRONMENT VARIABLE CHECK"
  Rails.logger.info "=" * 60
end
