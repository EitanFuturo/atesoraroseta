# robots.txt: keeps crawlers out of the admin and the login, and points them to the sitemap on this host.
class RobotsController < PublicController
  def show
    render plain: <<~ROBOTS
      User-agent: *
      Disallow: /admin
      Disallow: /session

      Sitemap: #{sitemap_url}
    ROBOTS
  end
end
