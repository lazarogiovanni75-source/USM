# Sora 2 HD Service for Image/Video Generation via Replicate
class SoraService
  class Error < StandardError; end

  def initialize
    @api_key = ENV.fetch('REPLICATE_API_KEY', ENV.fetch('DEFAPI_API_KEY', nil))
    @base_url = 'https://api.replicate.com/v1'
  end

  def generate_image(prompt:, size: '1024x1024')
    model_version = 'flux-schnell'
    
    body = {
      input: {
        prompt: prompt,
        width: size.split('x').first.to_i,
        height: size.split('x').last.to_i,
        num_outputs: 1
      }
    }

    make_request(:post, "/models/black-forest-labs/#{model_version}/predictions", body)
  end

  def generate_video(prompt:, duration: '5s')
    model_version = 'sora-2-hd'
    
    body = {
      input: {
        prompt: prompt,
        duration: duration,
        aspect_ratio: '16:9'
      }
    }

    make_request(:post, "/models/replicate/#{model_version}/predictions", body)
  end

  def get_prediction(prediction_url)
    uri = URI.parse(prediction_url)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    response = http.request(request)

    raise Error, "Failed to get prediction: #{response.body}" unless response.success?

    JSON.parse(response.body)
  end

  private

  def make_request(method, path, body)
    uri = URI.parse("#{@base_url}#{path}")
    request = case method
    when :post
      Net::HTTP::Post.new(uri)
    else
      raise Error, "Unsupported HTTP method: #{method}"
    end

    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = 'application/json'
    request.body = body.to_json

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 30
    http.read_timeout = 60

    response = http.request(request)

    unless response.success?
      raise Error, "API request failed: #{response.code} - #{response.body}"
    end

    JSON.parse(response.body)
  end
end
