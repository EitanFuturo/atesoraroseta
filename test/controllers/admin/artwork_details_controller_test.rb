require "test_helper"

class Admin::ArtworkDetailsControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:one)
    @artwork = artworks(:collage)
  end

  test "the work's page lists its details with their alt fields in the work's form" do
    get edit_admin_artwork_path(@artwork)

    assert_select "#detalles" do
      assert_select "h2", "Detalles (2)"
      assert_select "form[action=?] input[type=file][name='images[]'][multiple][data-direct-upload-url]", admin_artwork_details_path(@artwork)
      assert_select ".detail", 2
      assert_select "##{dom_id(artwork_details(:collage_first))} .detail__title", "Detalle 1 de 2"
      assert_select "input[name='artwork[details_attributes][0][id]'][form=artwork-form][value=?]", artwork_details(:collage_first).id.to_s
      assert_select "input#artwork_details_attributes_0_alt[form=artwork-form][value=?]", artwork_details(:collage_first).alt
      assert_select "##{dom_id(artwork_details(:collage_second))} .warning",
        text: "Falta el texto alternativo: ahora se usa «Collage de prueba (2/2)»."
      assert_select "button[form=?][data-turbo-confirm]", dom_id(artwork_details(:collage_second), :destroy)
      assert_select "button[type=submit][form=artwork-form]", "Guardar cambios"
    end
    assert_select "form##{dom_id(artwork_details(:collage_second), :destroy)}[hidden][action=?]",
      admin_artwork_detail_path(@artwork, artwork_details(:collage_second))
  end

  test "adding several details at once keeps the order they were chosen in, after the existing ones" do
    first = ActiveStorage::Blob.create_and_upload!(io: file_fixture("obra-01-d5.jpg").open, filename: "d5.jpg")
    second = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "d1.png")

    assert_difference -> { @artwork.details.count }, 2 do
      post admin_artwork_details_path(@artwork), params: { images: [ "", first.signed_id, second.signed_id ] }
    end

    assert_redirected_to edit_admin_artwork_path(@artwork, anchor: "detalles")
    assert_equal "Se han añadido 2 detalles.", flash[:notice]
    assert_equal [ "obra-01-d5.jpg", "small.png", "d5.jpg", "d1.png" ], @artwork.details.reload.map { |detail| detail.image.filename.to_s }
    assert_equal [ 1, 2, 3, 4 ], @artwork.details.map(&:position)
  end

  test "adding details as plain files (without JavaScript) works too" do
    post admin_artwork_details_path(@artwork), params: { images: [ fixture_file_upload("small.png", "image/png") ] }

    assert_equal "Se ha añadido 1 detalle.", flash[:notice]
    assert_equal "small.png", @artwork.details.reload.last.image.filename.to_s
  end

  test "a file that isn't an image is left out, with a Spanish message, and the rest are added" do
    image = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "bueno.png")
    text = ActiveStorage::Blob.create_and_upload!(io: file_fixture("not-an-image.txt").open, filename: "notas.txt")

    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ text ]) do
      post admin_artwork_details_path(@artwork), params: { images: [ text.signed_id, image.signed_id, "manipulado" ] }
    end

    assert_equal "Se ha añadido 1 detalle.", flash[:notice]
    assert_equal "No se han podido añadir 2 archivos:", flash[:alert]
    assert_equal [ "«notas.txt»: Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)", "Un archivo no se ha podido leer." ],
      flash[:alert_details]
    assert_equal 3, @artwork.details.count

    follow_redirect!
    assert_select ".flash--alert li", "«notas.txt»: Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)"
  end

  test "sending no file says so" do
    assert_no_difference -> { ArtworkDetail.count } do
      post admin_artwork_details_path(@artwork), params: { images: [ "" ] }
    end

    assert_equal "Elige al menos una foto para añadir.", flash[:alert]
  end

  test "deleting a detail" do
    assert_difference -> { @artwork.details.count }, -1 do
      delete admin_artwork_detail_path(@artwork, artwork_details(:collage_first))
    end

    assert_redirected_to edit_admin_artwork_path(@artwork, anchor: "detalles")
    assert_equal "Detalle eliminado.", flash[:notice]
    assert_equal [ 1 ], @artwork.details.reload.map(&:position)
  end

  test "a detail is only reached through its own work" do
    delete admin_artwork_detail_path(artworks(:range), artwork_details(:collage_first))

    assert_response :not_found
    assert ArtworkDetail.exists?(artwork_details(:collage_first).id)
  end

  test "the details' alt texts are saved with the work's form" do
    patch admin_artwork_path(@artwork), params: { artwork: { title: "Collage de prueba", details_attributes: {
      "0" => { id: artwork_details(:collage_first).id, alt: "Borde rasgado" },
      "1" => { id: artwork_details(:collage_second).id, alt: "Trama de puntos", position: 9, artwork_id: artworks(:range).id }
    } } }

    assert_redirected_to edit_admin_artwork_path(@artwork)
    assert_equal [ "Borde rasgado", "Trama de puntos" ], @artwork.details.reload.map(&:alt)
    assert_equal [ 1, 2 ], @artwork.details.map(&:position), "unpermitted keys are ignored"
    assert_equal @artwork, artwork_details(:collage_second).reload.artwork
  end

  test "the work's form can't create details or reach another work's" do
    assert_no_difference -> { ArtworkDetail.count } do
      patch admin_artwork_path(@artwork), params: { artwork: { details_attributes: { "0" => { alt: "Sin imagen" } } } }
    end
    assert_redirected_to edit_admin_artwork_path(@artwork)

    other = artworks(:range).details.create!(image: fixture_attachable("small.png"))
    patch admin_artwork_path(@artwork), params: { artwork: { details_attributes: { "0" => { id: other.id, alt: "Ajeno" } } } }
    assert_response :not_found
    assert_nil other.reload.alt
  end
end
