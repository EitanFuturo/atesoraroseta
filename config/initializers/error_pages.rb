# Error pages (overview §4.4 and §4.9), used wherever detailed exceptions are off (production):
# - 404 and 500 go through the routes (/404 and /500, ErrorsController): the 404 in the site's layout;
# - any other status (400, 406, 422…) gets its static page, public/<status>.html, as Rails does by default.
#   With `config.exceptions_app = routes` alone those would be empty pages, since the routes only know 404 and 500.
#
# Exceptions reach this app outside the middleware that adds the Content-Security-Policy header, so it is
# wrapped in that middleware: error pages carry the same policy as every other page.
Rails.application.configure do
  static_pages = ActionDispatch::PublicExceptions.new(Rails.public_path)
  dynamic_paths = %w[/404 /500].freeze

  config.exceptions_app = ActionDispatch::ContentSecurityPolicy::Middleware.new(
    ->(env) { (dynamic_paths.include?(env["PATH_INFO"]) ? Rails.application.routes : static_pages).call(env) }
  )
end
