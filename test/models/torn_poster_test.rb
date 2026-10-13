require "test_helper"

class TornPosterTest < ActiveSupport::TestCase
  def create_poster(**attributes)
    TornPoster.create!({ image: fixture_attachable("small.png") }.merge(attributes))
  end

  test "the fixtures are valid" do
    TornPoster.find_each { |poster| assert poster.valid?, poster.errors.full_messages.to_sentence }
  end

  test "only the image is required, and new photos are unpublished" do
    assert_includes TornPoster.new.tap(&:valid?).errors.full_messages, "Imagen es obligatoria"

    poster = create_poster
    assert poster.persisted?
    assert_not poster.published?
  end

  test "published and ordered" do
    assert_equal [ torn_posters(:street), torn_posters(:wall) ], TornPoster.published.ordered.to_a
    assert_equal [ torn_posters(:street), torn_posters(:wall), torn_posters(:draft) ], TornPoster.ordered.to_a
  end

  test "new photos go to the top, and photos move with acts_as_list" do
    poster = create_poster
    assert_equal [ poster, torn_posters(:street), torn_posters(:wall), torn_posters(:draft) ], TornPoster.ordered.to_a

    poster.move_to_bottom
    assert_equal poster, TornPoster.ordered.last
  end

  test "the alt text falls back to place and city" do
    assert_equal "Calle de Toledo, Madrid", torn_posters(:street).alt_text
    assert_equal "Cartel arrancado en rojos y negros", torn_posters(:wall).alt_text
    assert_equal "Lisboa", TornPoster.new(city: "Lisboa").alt_text
    assert_equal "", TornPoster.new.alt_text, "decorative when nothing is known"
  end

  test "flags photos without alt text" do
    assert torn_posters(:street).alt_missing?
    assert_not torn_posters(:wall).alt_missing?
    assert_equal [ torn_posters(:street), torn_posters(:draft) ].to_set, TornPoster.missing_alt.to_set
  end

  test "the label hides blank parts" do
    assert_equal "Madrid · 2024", torn_posters(:street).meta_line
    assert_equal "Lisboa · 2019–2020", torn_posters(:wall).meta_line
    assert_equal "Madrid", TornPoster.new(city: "Madrid").meta_line
    assert_equal "2024", TornPoster.new(years: "2024").meta_line
    assert_nil TornPoster.new(place: "Calle Mayor").meta_line

    assert TornPoster.new(place: "Calle Mayor").labelled?
    assert TornPoster.new(years: "2024").labelled?
    assert_not TornPoster.new.labelled?
  end

  test "the anchor is the tile's fragment id on /torn-posters" do
    poster = torn_posters(:street)

    assert_equal "poster-#{poster.id}", poster.anchor
  end
end
