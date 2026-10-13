require "test_helper"

# Titles, meta descriptions, canonical URLs, Open Graph and Twitter tags, favicons, sitemap.xml and robots.txt.
class SeoTest < ActionDispatch::IntegrationTest
  test "each page's title, description and canonical URL" do
    lead = Site::DEFAULTS.fetch("about_lead")
    {
      "/" => [ "Obra — atesoraroseta", lead, "http://www.example.com/" ],
      "/obra/collage-de-prueba" => [ "Collage de prueba — atesoraroseta",
        "Texto de prueba sobre la obra: de qué calle salieron los carteles y qué capas asoman.",
        "http://www.example.com/obra/collage-de-prueba" ],
      "/torn-posters" => [ "Torn Posters — atesoraroseta", "Fotografías de carteles arrancados que inspiran la obra.",
        "http://www.example.com/torn-posters" ],
      "/sobre-mi" => [ "Sobre mí — atesoraroseta", lead, "http://www.example.com/sobre-mi" ],
      "/contacto" => [ "Contacto — atesoraroseta", lead, "http://www.example.com/contacto" ]
    }.each do |path, (title, description, canonical)|
      get path
      assert_select "title", title
      assert_select "meta[name=description][content=?]", description
      assert_select "link[rel=canonical][href=?]", canonical
      assert_select "meta[property='og:title'][content=?]", title
      assert_select "meta[property='og:description'][content=?]", description
      assert_select "meta[property='og:url'][content=?]", canonical
      assert_select "meta[property='og:site_name'][content=atesoraroseta]"
      assert_select "meta[property='og:type'][content=website]"
      assert_select "meta[property='og:locale'][content=es_ES]"
    end
  end

  test "the home page and Contacto use the SEO description, and pages fall back to it" do
    sites(:main).update!(seo_description: "Collages de carteles arrancados.", torn_posters_intro: "")

    get "/"
    assert_select "meta[name=description][content=?]", "Collages de carteles arrancados."
    get "/contacto"
    assert_select "meta[name=description][content=?]", "Collages de carteles arrancados."
    get "/torn-posters"
    assert_select "meta[name=description][content=?]", "Collages de carteles arrancados."

    sites(:main).update!(seo_description: "")
    get "/"
    assert_select "meta[name=description]", 0
    assert_select "meta[property='og:description']", 0
  end

  test "an artwork's description is cut to about 155 characters" do
    artworks(:collage).update!(description: "<p>#{"Capas de papel rasgado al sol. " * 10}</p>")

    get "/obra/collage-de-prueba"
    description = css_select("meta[name=description]").first["content"]
    assert_operator description.length, :<=, 155
    assert description.end_with?("…")
  end

  test "the social image: the artwork's own on its page, else the first published artwork's" do
    get "/obra/obra-con-periodo"
    assert_select "meta[property='og:image'][content=?]", rails_storage_proxy_url(artworks(:range).image.variant(:og))
    assert_select "meta[property='og:image:alt'][content=?]", "Obra con periodo"
    assert_select "meta[property='og:image:type'][content='image/jpeg']"
    assert_select "meta[property='og:image:width'][content='1200']"
    assert_select "meta[property='og:image:height'][content='630']"
    assert_select "meta[name='twitter:card'][content=summary_large_image]"

    get "/sobre-mi"
    assert_select "meta[property='og:image'][content=?]", rails_storage_proxy_url(artworks(:collage).image.variant(:og))
    assert_select "meta[property='og:image:alt'][content=?]", "Collage de prueba en azules y ocres"
  end

  test "the social image: the site's own when set" do
    sites(:main).og_image.attach(fixture_attachable("small.png"))

    get "/contacto"
    assert_select "meta[property='og:image'][content=?]", rails_storage_proxy_url(sites(:main).og_image.variant(:og))
    assert_select "meta[property='og:image:alt']", 0

    get "/obra/collage-de-prueba"
    assert_select "meta[property='og:image'][content=?]", rails_storage_proxy_url(artworks(:collage).image.variant(:og))
  end

  test "favicons are linked only when one is uploaded" do
    get "/"
    assert_select "link[rel=icon]", 0
    assert_select "link[rel=apple-touch-icon]", 0

    favicon = sites(:main).favicon
    favicon.attach(fixture_attachable("small.png"))

    get "/"
    assert_select "link[rel=icon][type='image/png'][sizes='32x32'][href=?]", rails_storage_proxy_path(favicon.variant(:favicon_32))
    assert_select "link[rel=icon][type='image/png'][sizes='512x512'][href=?]", rails_storage_proxy_path(favicon.variant(:favicon_512))
    assert_select "link[rel=apple-touch-icon][sizes='180x180'][href=?]", rails_storage_proxy_path(favicon.variant(:favicon_180))
  end

  test "sitemap.xml lists the menu pages and only the published artworks, with lastmod" do
    get "/sitemap.xml"
    assert_response :success
    assert_equal "application/xml", response.media_type

    document = Nokogiri::XML(response.body)
    document.remove_namespaces!
    locations = document.xpath("//url/loc").map(&:text)
    assert_equal %w[
      http://www.example.com/ http://www.example.com/torn-posters http://www.example.com/sobre-mi
      http://www.example.com/contacto http://www.example.com/obra/collage-de-prueba
      http://www.example.com/obra/obra-con-periodo http://www.example.com/obra/obra-sin-datos
    ], locations
    assert_not_includes locations, "http://www.example.com/obra/obra-sin-publicar"

    collage = document.xpath("//url[loc='http://www.example.com/obra/collage-de-prueba']/lastmod").text
    assert_equal artworks(:collage).updated_at.utc.iso8601, collage
    assert_equal 7, document.xpath("//url/lastmod").size
  end

  test "robots.txt keeps crawlers out of the admin and the login, and points to the sitemap" do
    get "/robots.txt"
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal <<~ROBOTS, response.body
      User-agent: *
      Disallow: /admin
      Disallow: /session

      Sitemap: http://www.example.com/sitemap.xml
    ROBOTS
  end
end
