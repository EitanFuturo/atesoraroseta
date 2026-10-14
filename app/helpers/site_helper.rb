# The settings record in views, so the site's layout and partials would also work under a controller outside
# the public site. None renders layouts/application today (the login uses layouts/admin): this is a fallback.
# Public controllers provide their own memoised `site` (PublicController's helper_method), which takes precedence.
module SiteHelper
  def site
    @site ||= Site.current
  end
end
