require "test_helper"

# Torn Posters. Fixtures, in order: street (Calle de Toledo, Madrid, 2024, no alt), wall (Lisboa, 2019–2020,
# no place), draft (unpublished).
class TornPostersTest < ActionDispatch::IntegrationTest
  test "the page: hidden h1, the intro and the grid of published posters" do
    get "/torn-posters"
    assert_response :success

    assert_select "main.main-posters" do
      assert_select "h1.visually-hidden", "Torn Posters"
      assert_select "p.posters-intro", "Fotografías de carteles arrancados que inspiran la obra."
      assert_select ".photo-grid > figure.photo", 2
    end
    assert_equal [ torn_posters(:street).anchor, torn_posters(:wall).anchor ], css_select("figure.photo").map { |figure| figure["id"] }
  end

  test "each poster: a square-cropped image with its alt text, and the label" do
    get "/torn-posters"

    assert_select "figure.photo##{torn_posters(:street).anchor}" do
      assert_select "img.photo-img[alt='Calle de Toledo, Madrid'][width='800'][height='600']"
      assert_select "figcaption.hover-label" do
        assert_select "span.hover-title", "Calle de Toledo"
        assert_select "span.hover-meta", "Madrid · 2024"
      end
    end

    image = css_select("figure##{torn_posters(:street).anchor} img").first
    poster = torn_posters(:street).image
    assert_equal "#{rails_storage_proxy_path(poster.variant(:square_600))} 600w", image["srcset"]
    assert_equal "(min-width: 1440px) 313px, (min-width: 1024px) calc(22.78vw - 15px), " \
      "(min-width: 641px) calc(30.37vw - 13px), calc(45.55vw - 6px)", image["sizes"]
  end

  test "year ranges and missing places: no place line, and the range with an en dash" do
    get "/torn-posters"

    assert_select "figure##{torn_posters(:wall).anchor} figcaption" do
      assert_select "span.hover-title", 0
      assert_select "span.hover-meta", "Lisboa · 2019–2020"
    end
    assert_select "figure##{torn_posters(:wall).anchor} img[alt='Cartel arrancado en rojos y negros']"
  end

  test "blank parts of a label are left out, and a poster with nothing to say has no label" do
    torn_posters(:street).update!(city: "", years: "")
    poster = TornPoster.create!(published: true, image: fixture_attachable("small.png"))

    get "/torn-posters"
    assert_select "figure##{torn_posters(:street).anchor} span.hover-title", "Calle de Toledo"
    assert_select "figure##{torn_posters(:street).anchor} span.hover-meta", 0
    assert_select "figure##{poster.anchor} figcaption", 0
    assert_select "figure##{poster.anchor} img[alt='']"
  end

  test "the first row (4 photos) loads eagerly and the rest lazily" do
    4.times { TornPoster.create!(published: true, place: "Calle", image: fixture_attachable("small.png")) }

    get "/torn-posters"
    images = css_select(".photo-grid img").to_a
    assert_equal 6, images.size
    assert_equal "high", images.first["fetchpriority"]
    images.first(4).each { |image| assert_nil image["loading"] }
    images.last(2).each { |image| assert_equal "lazy", image["loading"] }
  end

  test "without an intro or posters, only the hidden heading remains" do
    sites(:main).update!(torn_posters_intro: "")
    TornPoster.update_all(published: false)

    get "/torn-posters"
    assert_select "h1.visually-hidden", "Torn Posters"
    assert_select "p.posters-intro", 0
    assert_select ".photo-grid", 0
  end
end
