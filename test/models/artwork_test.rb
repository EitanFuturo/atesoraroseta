require "test_helper"

class ArtworkTest < ActiveSupport::TestCase
  def create_artwork(**attributes)
    Artwork.create!({ title: "Obra nueva", image: fixture_attachable("small.png") }.merge(attributes))
  end

  test "the fixtures are valid" do
    Artwork.find_each { |artwork| assert artwork.valid?, artwork.errors.full_messages.to_sentence }
  end

  test "requires a title and an image, in Spanish" do
    artwork = Artwork.new

    assert_not artwork.valid?
    assert_includes artwork.errors.full_messages, "Título no puede estar en blanco"
    assert_includes artwork.errors.full_messages, "Imagen es obligatoria"
  end

  test "new works are unpublished" do
    assert_not create_artwork.published?
  end

  # Slugs

  test "generates the slug from the title on create" do
    assert_equal "obra-de-muestra-02", create_artwork(title: "Obra de muestra 02").slug
    assert_equal "tecnica-mixta-ano-2024", create_artwork(title: "  Técnica mixta: año 2024!  ").slug
  end

  test "adds -2, -3… when the slug is taken" do
    assert_equal "collage-de-prueba-2", create_artwork(title: "Collage de prueba").slug
    assert_equal "collage-de-prueba-3", create_artwork(title: "Collage de prueba").slug
  end

  test "falls back to a generic slug when the title has no letters or digits" do
    assert_equal "obra", create_artwork(title: "¿?").slug
    assert_equal "obra-2", create_artwork(title: "—").slug
  end

  test "editing the title never changes the slug" do
    artwork = artworks(:collage)
    artwork.update!(title: "Otro título")

    assert_equal "collage-de-prueba", artwork.reload.slug
  end

  test "the slug is editable, and a cleared slug is generated again from the title" do
    artwork = artworks(:collage)

    artwork.update!(slug: " Collage-Azul ")
    assert_equal "collage-azul", artwork.slug

    artwork.update!(title: "Collage rojo", slug: "")
    assert_equal "collage-rojo", artwork.slug
  end

  test "the slug must be lower-case letters, digits and single hyphens" do
    artwork = artworks(:collage)
    message = "Dirección (URL) solo puede tener letras minúsculas sin acentos, números y guiones (por ejemplo, obra-azul)"

    [ "obra azul", "obra--azul", "-obra", "obra-", "obra_azul", "canción" ].each do |slug|
      artwork.slug = slug
      assert_not artwork.valid?, slug
      assert_equal [ message ], artwork.errors.full_messages_for(:slug), slug
    end
  end

  test "the slug is unique" do
    artwork = artworks(:range)
    artwork.slug = "collage-de-prueba"

    assert_not artwork.valid?
    assert_includes artwork.errors.full_messages, "Dirección (URL) ya está en uso"
  end

  test "to_param is the stored slug, so artwork_path(artwork) is /obra/<slug>" do
    artwork = artworks(:collage)
    assert_equal "collage-de-prueba", artwork.to_param

    artwork.slug = "no valido"
    assert_equal "collage-de-prueba", artwork.to_param, "an unsaved edit doesn't change the URL"
    assert_nil Artwork.new.to_param
  end

  # Ordering

  test "published lists only published works" do
    assert_equal [ artworks(:collage), artworks(:range), artworks(:bare) ].to_set, Artwork.published.to_set
  end

  test "ordered is by position" do
    assert_equal [ artworks(:collage), artworks(:range), artworks(:draft), artworks(:bare) ], Artwork.ordered.to_a
  end

  test "ordered breaks position ties by the last year, most recent first, then by id" do
    Artwork.update_all(position: 1)

    expected = [ artworks(:draft), artworks(:collage), artworks(:range) ] # 2025, 2024, 2022–2023
    assert_equal expected, Artwork.ordered.to_a.first(3)
    assert_equal artworks(:bare), Artwork.ordered.last, "no year sorts last"
  end

  test "a range sorts by its last year" do
    Artwork.update_all(position: 1)
    artworks(:range).update_columns(year: 2020, year_end: 2025) # starts before collage's 2024, ends after it

    order = Artwork.ordered.to_a
    assert_operator order.index(artworks(:range)), :<, order.index(artworks(:collage))
  end

  test "new works go to the top" do
    artwork = create_artwork

    assert_equal 1, artwork.position
    assert_equal artwork, Artwork.ordered.first
    assert_equal [ 2, 3, 4, 5 ], [ artworks(:collage), artworks(:range), artworks(:draft), artworks(:bare) ].map { |a| a.reload.position }
  end

  test "works move with acts_as_list" do
    artworks(:bare).insert_at(1)
    assert_equal [ artworks(:bare), artworks(:collage), artworks(:range), artworks(:draft) ], Artwork.ordered.to_a

    artworks(:bare).reload.move_lower
    assert_equal [ artworks(:collage), artworks(:bare), artworks(:range), artworks(:draft) ], Artwork.ordered.to_a

    artworks(:draft).reload.move_higher
    assert_equal [ artworks(:collage), artworks(:bare), artworks(:draft), artworks(:range) ], Artwork.ordered.to_a
  end

  # Previous and next

  test "previous and next are the published neighbours, without wrap-around" do
    collage, range, bare = artworks(:collage), artworks(:range), artworks(:bare)

    assert_nil collage.previous
    assert_equal range, collage.next

    assert_equal collage, range.previous
    assert_equal bare, range.next, "skips the unpublished draft in between"

    assert_equal range, bare.previous
    assert_nil bare.next
  end

  test "an unpublished work (admin preview) gets the published works around it" do
    draft = artworks(:draft)

    assert_equal artworks(:range), draft.previous
    assert_equal artworks(:bare), draft.next
  end

  test "a lone published work has no neighbours" do
    Artwork.where.not(id: artworks(:collage).id).update_all(published: false)

    assert_nil artworks(:collage).previous
    assert_nil artworks(:collage).next
  end

  test "neighbours follow position changes after a reload" do
    range = artworks(:range)
    assert_equal artworks(:collage), range.previous

    artworks(:bare).insert_at(1)
    assert_equal artworks(:collage), range.reload.previous
    assert_nil artworks(:bare).reload.previous
  end

  # Alt text and labels

  test "the alt text falls back to the title" do
    assert_equal "Collage de prueba en azules y ocres", artworks(:collage).alt_text
    assert_equal "Obra con periodo", artworks(:range).alt_text
  end

  test "flags works without alt text" do
    assert artworks(:range).alt_missing?
    assert_not artworks(:collage).alt_missing?
    assert_equal [ artworks(:range) ], Artwork.missing_alt.to_a
  end

  test "meta_line joins the year and the medium with a middle dot, hiding blanks" do
    assert_equal "2024 · Carteles publicitarios arrancados sobre papel", artworks(:collage).meta_line
    assert_equal "2022–2023 · Carteles arrancados sobre tabla", artworks(:range).meta_line
    assert_equal "2025", artworks(:draft).meta_line
    assert_nil artworks(:bare).meta_line

    artwork = artworks(:collage)
    artwork.years = ""
    assert_equal "Carteles publicitarios arrancados sobre papel", artwork.meta_line
  end

  test "meta_description is the description as plain text, truncated" do
    assert_equal "Texto de prueba sobre la obra: de qué calle salieron los carteles y qué capas asoman.",
      artworks(:collage).meta_description

    artwork = artworks(:collage)
    artwork.update!(description: "<p>#{"palabra " * 40}</p>")
    assert_operator artwork.meta_description.length, :<=, 155
    assert artwork.meta_description.end_with?("palabra…")
  end

  test "meta_description falls back to title, year and medium" do
    assert_equal "Obra con periodo, 2022–2023. Carteles arrancados sobre tabla.", artworks(:range).meta_description
    assert_equal "Obra sin publicar, 2025.", artworks(:draft).meta_description
    assert_equal "Obra sin datos.", artworks(:bare).meta_description
  end

  test "destroying a work destroys its details" do
    assert_difference -> { ArtworkDetail.count }, -2 do
      artworks(:collage).destroy
    end
  end
end
