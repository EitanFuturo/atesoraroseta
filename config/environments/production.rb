require "active_support/core_ext/integer/time"
# Environment files run before autoloading is set up, so the middleware used below is required here.
require_relative "../../lib/www_redirect"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options). In production
  # storage/ is the Docker volume atesoraroseta_storage (no off-server copy for now: DEPLOY.md, "Turning backups on").
  config.active_storage.service = :local

  # kamal-proxy terminates SSL (Let's Encrypt) and talks plain HTTP to the app.
  config.assume_ssl = true

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # Because of assume_ssl every request counts as HTTPS, so kamal-proxy's health checks on /up, which
  # arrive over plain HTTP, are not redirected and need no exclusion.
  config.force_ssl = true

  # The site's address, atesoraroseta.com (APP_HOST in config/deploy.yml). Without it, as in a one-off
  # container that serves no requests, any host is accepted and nothing is redirected.
  if (app_host = ENV["APP_HOST"].presence)
    # Only requests for the site's two names reach the app (protection against DNS rebinding and forged
    # Host headers), except kamal-proxy's health checks, which address the container directly.
    config.hosts = [ app_host, "www.#{app_host}" ]
    config.host_authorization = { exclude: ->(request) { request.path == "/up" } }

    # www.<APP_HOST> answers with a 301 to the same path on APP_HOST, the canonical address.
    config.middleware.insert_after ActionDispatch::SSL, WwwRedirect, host: app_host

    # Absolute URLs built outside a request (jobs, the console) use the canonical address too.
    # Inside a request they use the request's host, which is APP_HOST once www is redirected.
    Rails.application.routes.default_url_options = { host: app_host, protocol: "https" }
    config.action_mailer.default_url_options = { host: app_host, protocol: "https" }
  end

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  # The jobs run inside Puma (SOLID_QUEUE_IN_PUMA in config/deploy.yml, see config/puma.rb), including the
  # recurring ones in config/recurring.yml such as the nightly uploads backup.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # Nothing in this app sends email: no password recovery and no notifications, so there is no SMTP.

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]
end
