module Admin
  # Every page under /admin. Login is required: Authentication's before_action, declared again here so
  # no admin page depends on what ApplicationController allows. Then the browser check, in the admin layout.
  class BaseController < ApplicationController
    before_action :require_authentication
    include BrowserSupport

    layout "admin"
  end
end
