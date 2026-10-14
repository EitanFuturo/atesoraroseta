require "test_helper"
require "open3"

# config/environments/production.rb is never loaded in tests, so this boots the app in the production
# environment in a separate process, as the container does (APP_HOST from config/deploy.yml), and sends
# requests through its real middleware stack. No database is touched.
class ProductionEnvironmentTest < ActiveSupport::TestCase
  SCRIPT = <<~'RUBY'
    requests = [
      [ "www.atesoraroseta.com", "/obra/obra-de-muestra-01?a=1", "GET" ],
      [ "172.18.0.5:80", "/up", "GET" ],
      [ "atesoraroseta.com", "/up", "GET" ],
      [ "otro-proyecto.example", "/", "GET" ]
    ]
    responses = requests.map do |host, path, verb|
      env = Rack::MockRequest.env_for("http://#{host}#{path}", method: verb, "HTTP_HOST" => host)
      status, headers, _ = Rails.application.call(env)
      [ status, headers["location"], headers["strict-transport-security"].present? ]
    end
    config = Rails.application.config
    puts JSON.generate(
      responses: responses,
      hosts: config.hosts.map(&:to_s),
      middleware: Rails.application.middleware.map(&:name).first(4),
      url_options: Rails.application.routes.default_url_options,
      assume_ssl: config.assume_ssl, force_ssl: config.force_ssl,
      storage: config.active_storage.service, queue_adapter: config.active_job.queue_adapter
    )
  RUBY

  test "production allows only the site's hosts, redirects www, and lets kamal-proxy's health check through" do
    env = { "RAILS_ENV" => "production", "APP_HOST" => "atesoraroseta.com", "SECRET_KEY_BASE_DUMMY" => "1",
            "RAILS_LOG_LEVEL" => "fatal" }
    output, errors, status = Open3.capture3(env, "bin/rails", "runner", SCRIPT, chdir: Rails.root)
    assert status.success?, errors
    result = JSON.parse(output.lines.last)

    www, health_check, health_check_by_name, other_host = result["responses"]
    assert_equal [ 301, "https://atesoraroseta.com/obra/obra-de-muestra-01?a=1", true ], www
    assert_equal [ 200, nil, true ], health_check, "plain HTTP to the container's address: not blocked, not redirected"
    assert_equal [ 200, nil, true ], health_check_by_name
    assert_equal 403, other_host.first

    assert_equal [ "atesoraroseta.com", "www.atesoraroseta.com" ], result["hosts"]
    assert_equal %w[ActionDispatch::HostAuthorization ActionDispatch::AssumeSSL ActionDispatch::SSL WwwRedirect],
      result["middleware"]
    assert_equal({ "host" => "atesoraroseta.com", "protocol" => "https" }, result["url_options"])
    assert result["assume_ssl"]
    assert result["force_ssl"]
    assert_equal "local", result["storage"]
    assert_equal "solid_queue", result["queue_adapter"]
  end
end
