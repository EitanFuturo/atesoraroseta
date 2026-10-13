require "test_helper"

class WwwRedirectTest < ActiveSupport::TestCase
  APP = ->(env) { [ 200, { "content-type" => "text/plain" }, [ "app" ] ] }

  def call(url, method: "GET", host: URI(url).host)
    WwwRedirect.new(APP, host: "atesoraroseta.com").call(Rack::MockRequest.env_for(url, method: method, "HTTP_HOST" => host))
  end

  test "www redirects permanently to the same path and query on the canonical host" do
    status, headers, body = call("https://www.atesoraroseta.com/obra/obra-de-muestra-01?a=1&b=2")

    assert_equal 301, status
    assert_equal "https://atesoraroseta.com/obra/obra-de-muestra-01?a=1&b=2", headers["location"]
    assert_empty body
  end

  test "the home page, any method, any case and any port redirect too" do
    assert_equal "https://atesoraroseta.com/", call("http://www.atesoraroseta.com")[1]["location"]
    assert_equal "https://atesoraroseta.com/", call("https://www.atesoraroseta.com/", method: "HEAD")[1]["location"]
    assert_equal "https://atesoraroseta.com/session", call("https://www.atesoraroseta.com/session", method: "POST")[1]["location"]
    assert_equal "https://atesoraroseta.com/contacto",
      call("https://WWW.Atesoraroseta.COM/contacto", host: "WWW.Atesoraroseta.COM")[1]["location"]
    assert_equal "https://atesoraroseta.com/up", call("http://www.atesoraroseta.com:8080/up", host: "www.atesoraroseta.com:8080")[1]["location"]
  end

  test "the redirect never leaves the configured host" do
    assert_equal "https://atesoraroseta.com//evil.example/x", call("https://www.atesoraroseta.com//evil.example/x")[1]["location"]
  end

  test "every other host reaches the app untouched" do
    [ "https://atesoraroseta.com/", "http://172.18.0.5/up", "https://www2.atesoraroseta.com/",
      "https://www.atesoraroseta.com.example/", "https://otro-proyecto.example/" ].each do |url|
      status, _, body = call(url)

      assert_equal 200, status, url
      assert_equal [ "app" ], body, url
    end
  end
end
