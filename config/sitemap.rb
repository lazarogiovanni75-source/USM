SitemapGenerator::Sitemap.default_host = 'https://www.ultimatesocialmedia01.com'

SitemapGenerator::Sitemap.public_path = 'public/'

SitemapGenerator::Sitemap.compress = false

SitemapGenerator::Sitemap.create do

  add '/',                changefreq: 'weekly',  priority: 1.0

  add '/users/sign_up',   changefreq: 'monthly', priority: 0.8

  add '/users/sign_in',   changefreq: 'monthly', priority: 0.5

end
