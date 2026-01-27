#!/usr/bin/env ruby

# PWA and WebView Testing Script
# Tests PWA features and WebView compatibility

require 'net/http'
require 'json'
require 'uri'

class PWATest
  def initialize(base_url)
    @base_url = base_url
    @results = []
  end

  def run_tests
    puts "🔍 Testing PWA and WebView Features..."
    puts "=" * 50
    
    test_manifest_accessibility
    test_service_worker_accessibility
    test_pwa_routes
    test_mobile_optimizations
    test_webview_detection
    
    print_results
  end

  private

  def test_manifest_accessibility
    puts "\n📱 Testing PWA Manifest..."
    
    begin
      uri = URI.join(@base_url, '/pwa/manifest')
      response = Net::HTTP.get(uri)
      manifest = JSON.parse(response)
      
      if manifest['name'] && manifest['icons']
        puts "✅ PWA manifest is accessible and valid"
        puts "   - App Name: #{manifest['name']}"
        puts "   - Icons: #{manifest['icons'].size} configured"
        @results << { test: 'PWA Manifest', status: 'PASS' }
      else
        puts "❌ PWA manifest missing required fields"
        @results << { test: 'PWA Manifest', status: 'FAIL' }
      end
    rescue => e
      puts "❌ PWA manifest test failed: #{e.message}"
      @results << { test: 'PWA Manifest', status: 'FAIL', error: e.message }
    end
  end

  def test_service_worker_accessibility
    puts "\n⚙️ Testing Service Worker..."
    
    begin
      uri = URI.join(@base_url, '/pwa/service-worker')
      response = Net::HTTP.get(uri)
      
      if response.include?('Service Worker: Loaded successfully')
        puts "✅ Service Worker is accessible and configured"
        @results << { test: 'Service Worker', status: 'PASS' }
      else
        puts "❌ Service Worker configuration issues detected"
        @results << { test: 'Service Worker', status: 'FAIL' }
      end
    rescue => e
      puts "❌ Service Worker test failed: #{e.message}"
      @results << { test: 'Service Worker', status: 'FAIL', error: e.message }
    end
  end

  def test_pwa_routes
    puts "\n🛣️ Testing PWA Routes..."
    
    routes = [
      '/pwa/manifest',
      '/pwa/service-worker',
      '/pwa/install-prompt',
      '/pwa/update-available',
      '/pwa/status'
    ]
    
    routes.each do |route|
      begin
        uri = URI.join(@base_url, route)
        response = Net::HTTP.get_response(uri)
        
        if response.is_a?(Net::HTTPSuccess)
          puts "✅ #{route} - OK"
          @results << { test: "Route #{route}", status: 'PASS' }
        else
          puts "❌ #{route} - #{response.code}"
          @results << { test: "Route #{route}", status: 'FAIL', error: "HTTP #{response.code}" }
        end
      rescue => e
        puts "❌ #{route} - Error: #{e.message}"
        @results << { test: "Route #{route}", status: 'FAIL', error: e.message }
      end
    end
  end

  def test_mobile_optimizations
    puts "\n📱 Testing Mobile Optimizations..."
    
    # Check for mobile-specific CSS
    begin
      uri = URI.join(@base_url, '/assets/mobile-webview.css')
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        puts "✅ Mobile WebView CSS is accessible"
        @results << { test: 'Mobile CSS', status: 'PASS' }
      else
        puts "⚠️ Mobile WebView CSS not found"
        @results << { test: 'Mobile CSS', status: 'WARNING' }
      end
    rescue => e
      puts "❌ Mobile CSS test failed: #{e.message}"
      @results << { test: 'Mobile CSS', status: 'FAIL', error: e.message }
    end
    
    # Check for mobile controller
    begin
      uri = URI.join(@base_url, '/assets/mobile_webview_controller.js')
      response = Net::HTTP.get_response(uri)
      
      if response.is_a?(Net::HTTPSuccess)
        puts "✅ Mobile WebView Controller is accessible"
        @results << { test: 'Mobile Controller', status: 'PASS' }
      else
        puts "⚠️ Mobile WebView Controller not found"
        @results << { test: 'Mobile Controller', status: 'WARNING' }
      end
    rescue => e
      puts "❌ Mobile Controller test failed: #{e.message}"
      @results << { test: 'Mobile Controller', status: 'FAIL', error: e.message }
    end
  end

  def test_webview_detection
    puts "\n🔍 Testing WebView Detection..."
    
    # Test PWA status endpoint
    begin
      uri = URI.join(@base_url, '/pwa/status')
      response = Net::HTTP.get(uri)
      status = JSON.parse(response)
      
      puts "✅ PWA Status endpoint working"
      puts "   - PWA Enabled: #{status['pwa_enabled']}"
      puts "   - Installable: #{status['installable']}"
      puts "   - Capabilities: #{status['capabilities'].join(', ')}"
      
      @results << { test: 'WebView Detection', status: 'PASS' }
    rescue => e
      puts "❌ PWA Status test failed: #{e.message}"
      @results << { test: 'WebView Detection', status: 'FAIL', error: e.message }
    end
  end

  def print_results
    puts "\n" + "=" * 50
    puts "📊 PWA & WebView Test Results"
    puts "=" * 50
    
    passed = @results.count { |r| r[:status] == 'PASS' }
    failed = @results.count { |r| r[:status] == 'FAIL' }
    warnings = @results.count { |r| r[:status] == 'WARNING' }
    
    puts "Passed: #{passed}"
    puts "Failed: #{failed}"
    puts "Warnings: #{warnings}"
    puts "Total: #{@results.length}"
    
    if failed > 0
      puts "\n❌ Failed Tests:"
      @results.select { |r| r[:status] == 'FAIL' }.each do |result|
        puts "   - #{result[:test]}: #{result[:error]}"
      end
    end
    
    if warnings > 0
      puts "\n⚠️ Warnings:"
      @results.select { |r| r[:status] == 'WARNING' }.each do |result|
        puts "   - #{result[:test]}"
      end
    end
    
    puts "\n🎯 Summary:"
    if failed == 0
      puts "✅ All core PWA and WebView features are working correctly!"
      puts "🚀 Your app is ready for WebView integration."
    else
      puts "⚠️ Some features need attention before WebView deployment."
    end
    
    puts "\n📚 Next Steps:"
    puts "1. Test on actual mobile devices"
    puts "2. Verify PWA installation prompts"
    puts "3. Test offline functionality"
    puts "4. Check touch interactions"
    puts "5. Monitor performance metrics"
  end
end

if __FILE__ == $0
  # Get base URL from environment or use default
  base_url = ENV['BASE_URL'] || 'http://localhost:3000'
  
  puts "Testing PWA and WebView features at: #{base_url}"
  
  tester = PWATest.new(base_url)
  tester.run_tests
end