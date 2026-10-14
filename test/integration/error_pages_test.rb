require "test_helper"

# The error pages as production shows them (config/initializers/error_pages.rb): the test environment shows
# detailed exceptions, so these tests switch to the production setting while they run.
class ErrorPagesTest < ActionDispatch::IntegrationTest
  test "a missing page is the 404 in the site's layout, built from the settings" do
    with_production_error_pages { get "/no-existe" }

    assert_response :not_found
    assert_select "title", "Página no encontrada — atesoraroseta"
    assert_select "header.site-header a.wordmark", "atesoraroseta"
    assert_select "a.nav-link[aria-current]", 0
    assert_select "main.main-contact .contact" do
      assert_select "p.label.page-label", "404"
      assert_select "h1.contact-headline", "Página no encontrada"
      assert_select "p.not-found-text", "La página que buscas no existe o ha cambiado de dirección."
      assert_select "a.text-link.standalone-link[href='/']", "Volver a la obra"
    end
    assert_nil response.headers["Set-Cookie"]
    assert_no_match(/<script/i, response.body)
    assert_match(/default-src 'self'/, response.headers["Content-Security-Policy"].to_s)
  end

  test "an unpublished or unknown artwork gets the same 404" do
    [ "/obra/obra-sin-publicar", "/obra/no-existe" ].each do |path|
      with_production_error_pages { get path }
      assert_response :not_found
      assert_select "h1", "Página no encontrada"
    end
  end

  test "the 404's texts come from the settings, and its text is left out when blank" do
    sites(:main).update!(not_found_title: "Aquí no hay nada", not_found_text: "", not_found_link_label: "Ir a la obra")

    with_production_error_pages { get "/no-existe" }
    assert_select "title", "Aquí no hay nada — atesoraroseta"
    assert_select "h1", "Aquí no hay nada"
    assert_select "p.not-found-text", 0
    assert_select "a.standalone-link", "Ir a la obra"
  end

  test "the 404 works without a settings row" do
    Site.delete_all

    with_production_error_pages { get "/no-existe" }
    assert_response :not_found
    assert_select "h1", "Página no encontrada"
  end

  test "other formats get an empty 404" do
    with_production_error_pages { get "/no-existe.json" }
    assert_response :not_found
    assert_empty response.body
  end

  test "a 500 shows the static page, with the content security policy" do
    status, headers, body = call_exceptions_app("/500")

    assert_equal 500, status
    assert_match(/default-src 'self'/, headers["content-security-policy"].to_s)
    assert_includes body, "<title>Algo ha fallado — atesoraroseta</title>"
  end

  test "other statuses show their static page" do
    status, _headers, body = call_exceptions_app("/422")
    assert_equal 422, status
    assert_includes body, "<title>No se ha podido completar — atesoraroseta</title>"

    status, _headers, body = call_exceptions_app("/400")
    assert_equal 400, status
    assert_includes body, "<title>Solicitud no válida — atesoraroseta</title>"
  end

  test "the static pages are Spanish, self-contained and in the site's colours" do
    %w[400 404 422 500].each do |status|
      html = Rails.public_path.join("#{status}.html").read
      assert_includes html, '<html lang="es">', status
      assert_includes html, "--ground: #222221", status
      assert_includes html, '"Bodoni Moda", "Bodoni 72", Didot, Georgia, serif', status
      assert_no_match(/<script|<link/i, html, status)
    end
  end

  private
    def with_production_error_pages
      env_config = Rails.application.env_config
      saved = env_config.slice("action_dispatch.show_exceptions", "action_dispatch.show_detailed_exceptions")
      env_config["action_dispatch.show_exceptions"] = :all
      env_config["action_dispatch.show_detailed_exceptions"] = false
      yield
    ensure
      env_config.merge!(saved)
    end

    # What ActionDispatch::ShowExceptions does with an error: call the exceptions app at /<status>.
    def call_exceptions_app(path)
      env = Rails.application.env_config.merge(
        Rack::MockRequest.env_for("http://www.example.com#{path}", "HTTP_HOST" => "www.example.com")
      )
      status, headers, body = Rails.application.config.exceptions_app.call(env)
      text = +""
      body.each { |part| text << part }
      body.close if body.respond_to?(:close)
      [ status, headers, text ]
    end
end
