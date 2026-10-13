require "test_helper"

# The route contract of overview §4.4: paths and helper names. Recognising a path needs its controller,
# so only the routes whose controllers exist are recognised here; the rest are checked by generation.
class RoutesTest < ActionDispatch::IntegrationTest
  test "public paths and helpers" do
    assert_equal "/", root_path
    assert_equal "/obra/collage-de-prueba", artwork_path(artworks(:collage))
    assert_equal "/obra/obra-con-periodo", artwork_path("obra-con-periodo")
    assert_equal "/torn-posters", torn_posters_path
    assert_equal "/torn-posters#poster-#{torn_posters(:wall).id}", torn_posters_path(anchor: torn_posters(:wall).anchor)
    assert_equal "/sobre-mi", about_path
    assert_equal "/contacto", contact_path
    assert_equal "/sitemap.xml", sitemap_path
    assert_equal "/robots.txt", robots_path
    assert_equal "http://www.example.com/obra/collage-de-prueba", artwork_url(artworks(:collage))
  end

  test "public routes point at the public controllers" do
    assert_generates "/", controller: "artworks", action: "index"
    assert_generates "/obra/collage-de-prueba", controller: "artworks", action: "show", slug: "collage-de-prueba"
    assert_generates "/torn-posters", controller: "torn_posters", action: "index"
    assert_generates "/sobre-mi", controller: "pages", action: "about"
    assert_generates "/contacto", controller: "pages", action: "contact"
    assert_generates "/sitemap.xml", controller: "sitemaps", action: "show", format: "xml"
    assert_generates "/robots.txt", controller: "robots", action: "show", format: "text"
    assert_generates "/404", controller: "errors", action: "not_found"
    assert_generates "/500", controller: "errors", action: "internal_error"
  end

  test "login, health check and the admin root" do
    assert_routing "/session/new", controller: "sessions", action: "new"
    assert_routing({ method: "post", path: "/session" }, controller: "sessions", action: "create")
    assert_routing({ method: "delete", path: "/session" }, controller: "sessions", action: "destroy")
    assert_routing "/up", controller: "rails/health", action: "show"
    assert_equal "/admin", admin_root_path
    assert_generates "/admin", controller: "admin/artworks", action: "index"
  end

  test "no password or sign-up routes" do
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    assert_empty paths.grep(/password|sign_?up|registration/)
    assert_not_includes paths, "/session/edit(.:format)"
  end
end
