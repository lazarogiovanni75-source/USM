class PwaController < ApplicationController
  # Render manifest with theme colors from design system
  def manifest
    # Extract theme colors from application.css if available
    @theme_color = extract_theme_color || '#a172f3'
    @background_color = extract_background_color || '#ffffff'
    
    render 'pwa/manifest', layout: false, content_type: 'application/json'
  end

  # Render service worker with enhanced caching
  def service_worker
    render 'pwa/service_worker', layout: false, content_type: 'application/javascript'
  end

  # Handle PWA installation events
  def install_prompt
    # This endpoint can be used to trigger custom install prompts
    render json: { 
      installable: pwa_installable?,
      manifest_url: pwa_manifest_url,
      service_worker_url: pwa_service_worker_url
    }
  end

  # Handle PWA update notifications
  def update_available
    render json: { 
      update_available: service_worker_update_available?,
      version: current_service_worker_version,
      message: 'A new version is available'
    }
  end

  # Get PWA status and capabilities
  def status
    render json: {
      pwa_enabled: pwa_enabled?,
      webview: webview?,
      installable: pwa_installable?,
      capabilities: pwa_capabilities,
      theme: current_theme
    }
  end

  private

  def extract_theme_color
    # Try to extract primary color from application.css
    begin
      css_path = Rails.root.join('app', 'assets', 'stylesheets', 'application.css')
      if File.exist?(css_path)
        content = File.read(css_path)
        # Look for --color-primary or similar CSS custom properties
        if content.match(/--color-primary:\s*([^;]+);/)
          return $1.strip
        end
      end
    rescue => e
      Rails.logger.warn "Could not extract theme color: #{e.message}"
    end
    nil
  end

  def extract_background_color
    # Try to extract background color from application.css
    begin
      css_path = Rails.root.join('app', 'assets', 'stylesheets', 'application.css')
      if File.exist?(css_path)
        content = File.read(css_path)
        # Look for --color-background or similar CSS custom properties
        if content.match(/--color-background:\s*([^;]+);/)
          return $1.strip
        end
      end
    rescue => e
      Rails.logger.warn "Could not extract background color: #{e.message}"
    end
    nil
  end

  def pwa_enabled?
    request.user_agent&.include?('Chrome') || 
    request.user_agent&.include?('Firefox') ||
    request.user_agent&.include?('Safari')
  end

  def webview?
    user_agent = request.user_agent.to_s.downcase
    user_agent.include?('wv') || 
    user_agent.include?('webview') ||
    # Common WebView patterns
    (user_agent.include?('android') && user_agent.include?('wv')) ||
    (user_agent.include?('iphone') && user_agent.include?('wv')) ||
    user_agent.match(/instagram|facebook|twitter|tiktok/)
  end

  def pwa_installable?
    # Check if the browser supports PWA installation
    pwa_enabled? && !webview? && request.get?
  end

  def pwa_capabilities
    capabilities = []
    capabilities << 'service_worker' if request.user_agent&.include?('ServiceWorker')
    capabilities << 'offline_support' if request.user_agent&.include?('Cache')
    capabilities << 'notifications' if request.user_agent&.include?('Notification')
    capabilities << 'background_sync' if request.user_agent&.include?('BackgroundSync')
    capabilities
  end

  def current_theme
    {
      primary: @theme_color || '#a172f3',
      background: @background_color || '#ffffff',
      text: '#1f2937'
    }
  end

  def pwa_manifest_url
    '/pwa/manifest'
  end

  def pwa_service_worker_url
    '/pwa/service-worker'
  end

  def service_worker_update_available?
    # This would typically check if a new service worker version is available
    # For now, we'll return false
    false
  end

  def current_service_worker_version
    '2.0.0'
  end
end