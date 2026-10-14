# Sends www.<host> to <host> with a 301, keeping the path and the query, so the site has one address.
# kamal-proxy serves both names, each with its own certificate; the redirect happens here, in the app.
#
#   use WwwRedirect, host: "atesoraroseta.com"
#   # GET https://www.atesoraroseta.com/obra/x?y=1 → 301 Location: https://atesoraroseta.com/obra/x?y=1
#
# config/environments/production.rb inserts it with APP_HOST, right after ActionDispatch::SSL, so the
# redirect carries the HSTS header too. The target host is the configured one, never the request's.
class WwwRedirect
  def initialize(app, host:)
    @app = app
    @host = host.to_s.downcase
    @www_host = "www.#{@host}"
  end

  def call(env)
    request = Rack::Request.new(env)
    return @app.call(env) unless request.host.to_s.downcase == @www_host

    [ 301, { "location" => "https://#{@host}#{path_and_query(request)}", "content-type" => "text/plain" }, [] ]
  end

  private
    def path_and_query(request)
      path = request.fullpath
      path.start_with?("/") ? path : "/#{path}"
    end
end
