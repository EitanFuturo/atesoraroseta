require "test_helper"

# Obra (the grid of tiles) and the artwork pages. Fixtures, in Obra order: collage (everything, 2 details),
# range (2022–2023, no alt, no details), draft (unpublished), bare (only a title and an image).
class ArtworksTest < ActionDispatch::IntegrationTest
  test "Obra lists the published works in order, each tile linking to its page" do
    get "/"

    assert_select "main.main-obra h1.visually-hidden", "Obra"
    assert_equal %w[/obra/collage-de-prueba /obra/obra-con-periodo /obra/obra-sin-datos],
      css_select(".work-grid > a.work").map { |tile| tile["href"] }
  end

  test "a tile is a link around the frame, the image and the hover label" do
    get "/"

    assert_select ".work-grid > a.work[href='/obra/collage-de-prueba']" do
      assert_select "> figure.work-frame[style='width: 93.81%; aspect-ratio: 1179 / 1571']" do
        assert_select "> img.work-img[alt='Collage de prueba en azules y ocres']"
        assert_select "> figcaption.hover-label" do
          assert_select "> span.hover-title", "Collage de prueba"
          assert_select "> span.hover-meta", "2024 · Carteles publicitarios arrancados sobre papel"
        end
      end
    end

    # 800×600: a landscape work fills its cell's width.
    assert_select "a.work[href='/obra/obra-con-periodo'] figure.work-frame[style='width: 100%; aspect-ratio: 800 / 600']"
  end

  test "a tile's image has a srcset of the variants that exist, sizes, and the original's width and height" do
    get "/"
    image = css_select("a.work[href='/obra/collage-de-prueba'] img").first
    collage = artworks(:collage).image

    assert_equal "1179", image["width"]
    assert_equal "1571", image["height"]
    assert_equal "#{rails_storage_proxy_path(collage.variant(:width_600))} 600w, #{rails_storage_proxy_path(collage.variant(:width_1200))} 1179w", image["srcset"]
    assert_equal rails_storage_proxy_path(collage.variant(:width_1200)), image["src"]
    assert_equal "(max-width: 640px) 91.1vw, (min-width: 1440px) 376px, (min-width: 1100px) 26.06vw, " \
      "(min-width: 720px) calc(42.74vw - 16px), 85.47vw", image["sizes"]
    assert_match %r{\A/rails/active_storage/representations/proxy/}, image["src"]
  end

  test "the first row of tiles loads eagerly, the first with high priority, and the rest lazily" do
    2.times do |index|
      Artwork.create!(title: "Obra nueva #{index}", published: true, image: fixture_attachable("small.png")).move_to_bottom
    end

    get "/"
    images = css_select(".work-grid img").to_a
    assert_equal 5, images.size

    assert_equal "high", images.first["fetchpriority"]
    images.first(3).each { |image| assert_nil image["loading"] }
    images.drop(1).each { |image| assert_nil image["fetchpriority"] }
    images.last(2).each do |image|
      assert_equal "lazy", image["loading"]
      assert_equal "async", image["decoding"]
    end
  end

  test "a tile's hover meta hides what is blank" do
    artworks(:range).update!(medium: "")
    artworks(:bare).update!(medium: "Collage")

    get "/"
    assert_select "a.work[href='/obra/collage-de-prueba'] .hover-meta", "2024 · Carteles publicitarios arrancados sobre papel"
    assert_select "a.work[href='/obra/obra-con-periodo'] .hover-meta", "2022–2023"
    assert_select "a.work[href='/obra/obra-sin-datos'] .hover-meta", "Collage"

    artworks(:bare).update!(medium: "")
    get "/"
    assert_select "a.work[href='/obra/obra-sin-datos'] .hover-title", "Obra sin datos"
    assert_select "a.work[href='/obra/obra-sin-datos'] .hover-meta", 0
  end

  test "the artwork page: back link, hero, title, data rows, description and details link" do
    get "/obra/collage-de-prueba"
    assert_response :success

    assert_select "main.main-artwork" do
      assert_select "a.quiet-link.back-link[href='/'] span", "Obra"
      assert_select "a.back-link svg[aria-hidden=true] path[d='M13 7H1.5M6 2.5 1.5 7 6 11.5']"
      assert_select "section.artwork-hero[aria-labelledby=titulo-obra]" do
        assert_select ".artwork-media img.artwork-img[width='1179'][height='1571'][fetchpriority=high]"
        assert_select ".artwork-text h1#titulo-obra.artwork-title", "Collage de prueba"
      end
    end

    rows = css_select("dl.artwork-data .artwork-data-row").map { |row| [ row.at("dt").text, row.at("dd").text ] }
    assert_equal [ [ "Año", "2024" ], [ "Técnica", "Carteles publicitarios arrancados sobre papel" ], [ "Medidas", "120 × 90 cm" ] ], rows
    assert_select "dl.artwork-data dt.label", 3
    assert_select "dd.artwork-medium", 1

    assert_select ".artwork-description.rich-text p", /Texto de prueba sobre la obra/
    assert_select "a.text-link.details-link[href='#detalles']", "Ver los 2 detalles"
  end

  test "the hero is eager, high priority, and sized per image: at most 860px tall and never upscaled" do
    get "/obra/collage-de-prueba"
    hero = css_select("img.artwork-img").first
    assert_nil hero["loading"]
    assert_equal "(min-width: 1092px) 646px, (min-width: 1010px) calc(86.65vw - 300px), (min-width: 710px) 646px, 91.1vw",
      hero["sizes"]

    # 800×600: 860px tall would be 1147px wide, so the original's width caps it.
    get "/obra/obra-con-periodo"
    hero = css_select("img.artwork-img").first
    assert_equal "(min-width: 1270px) 800px, (min-width: 1010px) calc(86.65vw - 300px), (min-width: 879px) 800px, 91.1vw",
      hero["sizes"]
  end

  test "the details: a section of lazy detail photos in order, with their alt texts" do
    get "/obra/collage-de-prueba"

    assert_select "section#detalles.details[aria-labelledby=titulo-detalles]" do
      assert_select "h2#titulo-detalles.label.details-title", "Detalles"
      assert_select ".details-columns > figure.detail > img.detail-img", 2
    end

    images = css_select("figure.detail img")
    assert_equal [ "Detalle: borde rasgado con marcas de imprenta", "Collage de prueba (2/2)" ], images.map { |image| image["alt"] }
    images.each do |image|
      assert_equal "lazy", image["loading"]
      assert_equal "(min-width: 1440px) 422px, (min-width: 1058px) calc(30.37vw - 16px), " \
        "(min-width: 702px) calc(45.55vw - 12px), 91.1vw", image["sizes"]
      assert image["width"].present? && image["height"].present? && image["srcset"].present?
    end
  end

  test "one detail gets the singular link" do
    artwork_details(:collage_second).destroy

    get "/obra/collage-de-prueba"
    assert_select "a.details-link", "Ver el detalle"
    assert_select "figure.detail", 1
  end

  test "without details there is no details link or section" do
    get "/obra/obra-con-periodo"

    assert_select "a.details-link", 0
    assert_select "section#detalles", 0
  end

  test "empty data rows, description and details are left out" do
    get "/obra/obra-sin-datos"

    assert_select "h1#titulo-obra", "Obra sin datos"
    assert_select "dl.artwork-data", 0
    assert_select ".artwork-description", 0
    assert_select "a.details-link", 0

    artworks(:bare).update!(medium: "Collage")
    get "/obra/obra-sin-datos"
    assert_equal [ [ "Técnica", "Collage" ] ],
      css_select("dl.artwork-data .artwork-data-row").map { |row| [ row.at("dt").text, row.at("dd").text ] }
  end

  test "previous and next follow the published works, with no wrap-around" do
    get "/obra/collage-de-prueba"
    assert_select "nav.pager[aria-label='Otras obras'] a.pager-link", 1
    assert_select "a.pager-link.pager-next[href='/obra/obra-con-periodo']" do
      assert_select ".pager-label span", "Siguiente"
      assert_select ".pager-label svg path[d='M1 7h11.5M8 2.5 12.5 7 8 11.5']"
      assert_select ".pager-title", "Obra con periodo"
    end

    get "/obra/obra-con-periodo"
    assert_equal %w[/obra/collage-de-prueba /obra/obra-sin-datos], css_select("a.pager-link").map { |link| link["href"] }
    assert_select "a.pager-link:not(.pager-next) .pager-label span", "Anterior"

    # The draft between them is skipped, and the last work has no next.
    get "/obra/obra-sin-datos"
    assert_equal %w[/obra/obra-con-periodo], css_select("a.pager-link").map { |link| link["href"] }
    assert_select "a.pager-next", 0
  end

  test "a single published work has no previous/next navigation" do
    Artwork.where.not(id: artworks(:collage).id).update_all(published: false)

    get "/obra/collage-de-prueba"
    assert_select "nav.pager", 0
  end

  test "year ranges read 2022–2023 with an en dash in the tile, the data rows and the title fallback" do
    get "/"
    assert_select "a.work[href='/obra/obra-con-periodo'] .hover-meta", "2022–2023 · Carteles arrancados sobre tabla"

    get "/obra/obra-con-periodo"
    assert_select ".artwork-data-row dd", "2022–2023"
    assert_select "meta[name=description][content=?]", "Obra con periodo, 2022–2023. Carteles arrancados sobre tabla."
  end

  test "an unpublished work is a 404 for visitors" do
    get "/obra/obra-sin-publicar"
    assert_response :not_found
  end

  test "a signed-in admin previews an unpublished work with a notice, uncached" do
    sign_in_as users(:one)

    get "/obra/obra-sin-publicar"
    assert_response :success
    assert_select "p.preview-notice", I18n.t("public.preview_notice")
    assert_select "h1#titulo-obra", "Obra sin publicar"
    assert_equal "private, no-store", response.headers["Cache-Control"]

    get "/obra/collage-de-prueba"
    assert_select "p.preview-notice", 0
    assert_no_match(/no-store/, response.headers["Cache-Control"])
  end

  test "an unknown slug is a 404" do
    get "/obra/no-existe"
    assert_response :not_found
  end
end
