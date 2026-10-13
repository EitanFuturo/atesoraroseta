require "test_helper"

# Every public page: renders with content and without, the shared header, the copy from the settings record,
# and the privacy rules of overview §4.6 (no cookies, no JavaScript, a CSP header).
class PublicPagesTest < ActionDispatch::IntegrationTest
  PAGES = {
    "/" => :work,
    "/obra/collage-de-prueba" => :work,
    "/torn-posters" => :torn_posters,
    "/sobre-mi" => :about,
    "/contacto" => :contact
  }.freeze

  MENU = { work: "/", torn_posters: "/torn-posters", about: "/sobre-mi", contact: "/contacto" }.freeze

  test "every page renders with the fixtures" do
    PAGES.each_key do |path|
      get path
      assert_response :success, path
      assert_select "html[lang=es]"
      assert_select "main", 1
    end
  end

  test "every page renders with an empty database and no settings row" do
    empty_the_database

    [ "/", "/torn-posters", "/sobre-mi", "/contacto", "/sitemap.xml", "/robots.txt" ].each do |path|
      get path
      assert_response :success, path
    end

    get "/"
    assert_select "title", "Obra — atesoraroseta"
    assert_select ".work-grid", 0
    assert_select "meta[property='og:image']", 0

    get "/obra/collage-de-prueba"
    assert_response :not_found
  end

  test "the header: the wordmark links home and the menu marks the current section" do
    PAGES.each do |path, section|
      get path
      assert_select "header.site-header a.wordmark[href='/']", "atesoraroseta"
      assert_select "nav[aria-label=Principal] ul.nav-list li a.nav-link", 4
      assert_select "a.nav-link[aria-current=page]", 1, path
      assert_select "a.nav-link[aria-current=page][href='#{MENU.fetch(section)}']", 1, path
    end
  end

  test "the menu's order and labels come from the settings" do
    get "/"
    assert_equal [ "Obra", "Torn Posters", "Sobre mí", "Contacto" ], css_select("a.nav-link").map(&:text)
  end

  test "changing a site text changes the pages" do
    sites(:main).update!(wordmark: "rosetta", nav_work_label: "Trabajos", nav_contact_label: "Escribir",
      details_label: "Fragmentos", year_label: "Fecha", contact_headline: "Hablemos")

    get "/"
    assert_select "title", "Trabajos — rosetta"
    assert_select "a.wordmark", "rosetta"
    assert_select "h1.visually-hidden", "Trabajos"
    assert_select "a.nav-link[href='/']", "Trabajos"

    get "/obra/collage-de-prueba"
    assert_select "a.back-link span", "Trabajos"
    assert_select "h2#titulo-detalles", "Fragmentos"
    assert_select ".artwork-data dt", text: "Fecha"

    get "/contacto"
    assert_select "title", "Escribir — rosetta"
    assert_select "h1", "Escribir"
    assert_select "p.contact-headline", "Hablemos"
  end

  test "public responses set no cookie, have no script tags and carry the content security policy" do
    [ *PAGES.keys, "/sitemap.xml", "/robots.txt" ].each do |path|
      get path
      assert_nil response.headers["Set-Cookie"], "#{path} sets a cookie"
      assert_no_match(/<script/i, response.body, "#{path} has a script tag")
      assert_match(/default-src 'self'/, response.headers["Content-Security-Policy"].to_s, path)
    end
  end

  test "the public layout links its three stylesheets by name and preloads two fonts, with no JavaScript" do
    get "/"
    hrefs = css_select("link[rel=stylesheet]").map { |link| link["href"] }
    assert_equal 3, hrefs.size
    assert_match %r{/assets/fonts-\h+\.css}, hrefs[0]
    assert_match %r{/assets/site-\h+\.css}, hrefs[1]
    assert_match %r{/assets/layout-\h+\.css}, hrefs[2]

    preloads = css_select("link[rel=preload][as=font]")
    assert_equal 2, preloads.size
    assert_match %r{/assets/jost-normal-latin-\h+\.woff2}, preloads[0]["href"]
    assert_match %r{/assets/bodoni-moda-normal-latin-\h+\.woff2}, preloads[1]["href"]
    preloads.each do |link|
      assert_equal "font/woff2", link["type"]
      assert_equal "anonymous", link["crossorigin"]
    end

    assert_select "meta[name=csrf-token]", 0
    assert_select "meta[name=csp-nonce]", 0
  end

  test "the only inline styles on public pages are the tiles' frames" do
    sites(:main).update!(about_body: '<p>Texto <mark style="color: var(--highlight-1)">resaltado</mark>.</p>')
    artworks(:collage).update!(description: '<p style="text-align: center">Centrado <span style="color: red">rojo</span></p>')

    PAGES.each_key do |path|
      get path
      styled = css_select("[style]")
      assert styled.all? { |element| element.name == "figure" && element["class"] == "work-frame" },
        "#{path} has inline styles on #{styled.map(&:name).uniq.inspect}"
    end

    get "/sobre-mi"
    assert_select ".about-body mark", "resaltado"
    get "/obra/collage-de-prueba"
    assert_select ".artwork-description span", "rojo"
  end

  private
    def empty_the_database
      ActiveStorage::Attachment.delete_all
      ActionText::RichText.delete_all
      ArtworkDetail.delete_all
      Artwork.delete_all
      TornPoster.delete_all
      Site.delete_all
    end
end
