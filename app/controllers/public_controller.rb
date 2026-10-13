# The base of the public site's controllers: no login, the site's layout (layouts/application), and the
# settings record as the `site` helper.
#
# Public pages set no cookies (overview §4.6), so nothing in them may touch the session or the flash: the
# layout has no csrf_meta_tags and no forms, and `authenticated?` (the admin preview) only reads the signed
# session cookie.
class PublicController < ApplicationController
  allow_unauthenticated_access

  layout "application"

  helper_method :site

  private
    # The stored settings, or an unsaved record with the default texts before the seeds have run.
    def site
      @site ||= Site.current
    end
end
