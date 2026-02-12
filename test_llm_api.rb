#!/usr/bin/env ruby
require_relative 'config/environment'

puts "Testing OpenAI API key..."

api_key = ENV.fetch('OPENAI_API_KEY')
puts "OPENAI_API_KEY: #{api_key[0..15]}..."

begin
  puts "Testing LlmService..."
  response = LlmService.call_blocking(
    prompt: "Say 'Hello, voice works!' in exactly 5 words",
    system: "You are a helpful voice assistant"
  )
  puts "SUCCESS! Response: #{response}"
rescue LlmService::LlmError => e
  puts "LlmError: #{e.message}"
rescue => e
  puts "Error: #{e.class} - #{e.message[0..300]}"
end
