require_relative "../admin_system_test_case"

class Admin::ArtworkDetailsTest < AdminSystemTestCase
  setup { @artwork = artworks(:collage) }

  test "uploading several details and editing their alt texts" do
    visit edit_admin_artwork_path(@artwork)

    within "#detalles" do
      attach_file "Añadir detalles", [ file_fixture("obra-01-d5.jpg"), file_fixture("small.png") ], make_visible: true
      assert_selector ".uploads li", count: 2
      assert_selector ".uploads li .uploads__status", text: "Lista para subir", count: 2
      click_on "Subir los detalles"
    end

    assert_text "Se han añadido 2 detalles."
    within "#detalles" do
      assert_selector "h2", text: "Detalles (4)"
      assert_selector ".detail__title", text: "Detalle 4 de 4"

      fill_in "artwork_details_attributes_2_alt", with: "Detalle: borde rasgado sobre azul"
      fill_in "artwork_details_attributes_3_alt", with: "Detalle: trama de puntos ocre"
      click_on "Guardar cambios"
    end

    assert_text "Cambios guardados."
    assert_equal [ "obra-01-d5.jpg", "small.png" ], @artwork.details.reload.last(2).map { |detail| detail.image.filename.to_s }
    assert_equal [ "Detalle: borde rasgado sobre azul", "Detalle: trama de puntos ocre" ], @artwork.details.last(2).map(&:alt)
    assert_no_browser_errors
  end

  test "deleting a detail asks first" do
    visit edit_admin_artwork_path(@artwork)

    within "#detalles" do
      accept_confirm("¿Eliminar el detalle 2? No se puede deshacer.") do
        click_on "Eliminar Detalle 2 de 2"
      end
    end

    assert_text "Detalle eliminado."
    assert_equal [ artwork_details(:collage_first) ], @artwork.details.reload.to_a
  end

  test "deleting a detail with unsaved changes in the form asks first" do
    visit edit_admin_artwork_path(@artwork)
    fill_in "Título", with: "Título sin guardar"

    dismiss_confirm("Hay cambios sin guardar en esta página. Si continúas, se perderán. ¿Continuar?") do
      within("#detalles") { click_on "Eliminar Detalle 2 de 2" }
    end

    assert_field "Título", with: "Título sin guardar"
    assert_equal 2, @artwork.details.count
  end
end
