# The settings record in views, so the site's layout and partials also work under controllers outside the
# public site (the login page renders in layouts/application unless it sets a layout of its own). Public
# controllers provide their own memoised `site` (PublicController's helper_method), which takes precedence.
module SiteHelper
  def site
    @site ||= Site.current
  end
end
