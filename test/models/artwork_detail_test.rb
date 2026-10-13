require "test_helper"

class ArtworkDetailTest < ActiveSupport::TestCase
  def add_detail(artwork, **attributes)
    artwork.details.create!({ image: fixture_attachable("obra-01-d5.jpg") }.merge(attributes))
  end

  test "the fixtures are valid" do
    ArtworkDetail.find_each { |detail| assert detail.valid?, detail.errors.full_messages.to_sentence }
  end

  test "requires an artwork and an image" do
    detail = ArtworkDetail.new

    assert_not detail.valid?
    assert_includes detail.errors.full_messages, "Obra debe existir"
    assert_includes detail.errors.full_messages, "Imagen es obligatoria"
  end

  test "details come in their own order" do
    assert_equal [ artwork_details(:collage_first), artwork_details(:collage_second) ], artworks(:collage).details.to_a
  end

  test "new details go to the end of their artwork's list" do
    detail = add_detail(artworks(:collage))
    other = add_detail(artworks(:range))

    assert_equal 3, detail.position
    assert_equal detail, artworks(:collage).details.reload.last
    assert_equal 1, other.position, "each artwork has its own list"
  end

  test "details move within their artwork" do
    first, second = artwork_details(:collage_first), artwork_details(:collage_second)
    third = add_detail(artworks(:collage))

    third.move_to_top
    assert_equal [ third, first, second ], artworks(:collage).details.reload.to_a

    first.reload.move_lower
    assert_equal [ third, second, first ], artworks(:collage).details.reload.to_a
  end

  test "the alt text falls back to the artwork title and the detail's number" do
    assert_equal "Detalle: borde rasgado con marcas de imprenta", artwork_details(:collage_first).alt_text
    assert_equal "Collage de prueba (2/2)", artwork_details(:collage_second).alt_text

    third = add_detail(artworks(:collage))
    assert_equal "Collage de prueba (3/3)", artworks(:collage).details.reload.last.alt_text
    assert_equal 3, third.number
  end

  test "flags details without alt text" do
    assert artwork_details(:collage_second).alt_missing?
    assert_not artwork_details(:collage_first).alt_missing?
    assert_equal [ artwork_details(:collage_second) ], ArtworkDetail.missing_alt.to_a
  end

  test "changing a detail touches its artwork" do
    artwork = artworks(:collage)

    travel 1.minute do
      assert_changes -> { artwork.reload.updated_at } do
        artwork_details(:collage_first).update!(alt: "Otro texto")
      end
    end
  end
end
