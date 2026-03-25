class TestAnthropicController < ApplicationController
  before_action :authenticate_user!
  
  def test
    require 'net/http'
    require 'uri'
    require 'json'
    
    api_key = ENV['ANTHROPIC_API_KEY']
    model = ENV.fetch('ANTHROPIC_MODEL', 'claude-3-5-sonnet-20240620')
    
    if api_key.blank?
      render json: { error: 'ANTHROPIC_API_KEY not set', env_keys: ENV.keys.select { |k| k.include?('ANTHROPIC') } }, status: 500
      return
    end
    
    uri = URI("https://api.anthropic.com/v1/messages")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30
    
    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['x-api-key'] = api_key
    request['anthropic-version'] = '2023-06-01'
    request.body = {
      model: model,
      max_tokens: 100,
      messages: [{ role: 'user', content: 'Say hello' }]
    }.to_json
    
    response = http.request(request)
    
    result = {
      status: response.code,
      api_key_prefix: api_key[0..15] + '...',
      model: model,
      response_body: JSON.parse(response.body) rescue response.body[0..500]
    }
    
    render json: result
  rescue => e
    render json: { error: e.message, backtrace: e.backtrace.first(5) }, status: 500
  end
end
