class SitemapsController < ApplicationController
  # Disable CSRF for sitemap requests
  skip_before_action :verify_authenticity_token, raise: false

  def index
    @sitemaps = Dir[Rails.root.join('public/sitemaps/*.xml')]
    render template: "sitemaps/index", formats: [:xml]
  end

  def show
    sitemap_name = params[:sitemap]

    if sitemap_name.present?
      sitemap_file = SitemapGenerator::Sitemap.public_path(sitemap_name)

      if File.exist?(sitemap_file)
        send_file sitemap_file, type: "application/xml", disposition: "inline"
      else
        render xml: { error: "Sitemap not found" }.to_xml, status: :not_found
      end
    else
      redirect_to sitemaps_url(format: :xml)
    end
  end
end
