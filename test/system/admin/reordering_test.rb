require_relative "../admin_system_test_case"

class Admin::ReorderingTest < AdminSystemTestCase
  include ActionView::RecordIdentifier

  test "reordering works with the arrows, keeping the focus on the arrow" do
    visit admin_artworks_path

    within("##{dom_id(artworks(:range))}") { click_on "Subir «Obra con periodo» un puesto" }

    assert_text "«Obra con periodo» ha subido un puesto."
    assert_equal [ "Obra con periodo", "Collage de prueba", "Obra sin publicar", "Obra sin datos" ], all("tbody .records__title").map(&:text)
    # Now first, it can't go up any more: the focus moves to its other arrow.
    assert_equal "↓Bajar «Obra con periodo» un puesto", page.evaluate_script("document.activeElement.textContent").squish

    within("##{dom_id(artworks(:draft))}") { click_on "Bajar «Obra sin publicar» un puesto" }

    assert_text "«Obra sin publicar» ha bajado un puesto."
    assert_equal [ "Obra con periodo", "Collage de prueba", "Obra sin datos", "Obra sin publicar" ], all("tbody .records__title").map(&:text)
    assert_equal %w[obra-con-periodo collage-de-prueba obra-sin-datos obra-sin-publicar], Artwork.ordered.pluck(:slug)
    assert_no_browser_errors
  end

  test "reordering a work's details" do
    artwork = artworks(:collage)
    visit edit_admin_artwork_path(artwork)

    within("#detalles") { click_on "Bajar el detalle 1 un puesto" }

    assert_text "El detalle ha bajado un puesto."
    assert_equal [ artwork_details(:collage_second), artwork_details(:collage_first) ], artwork.details.reload.to_a
    # Now last, it can't go down any more: the focus is on its other arrow.
    assert_equal "↑Subir el detalle 2 un puesto", page.evaluate_script("document.activeElement.textContent").squish
    within("#detalles") do
      assert_selector ".detail:first-child .detail__title", text: "Detalle 1 de 2"
      assert_field "artwork_details_attributes_1_alt", with: artwork_details(:collage_first).alt
    end
  end

  test "moving a detail with unsaved changes in the form asks first" do
    visit edit_admin_artwork_path(artworks(:collage))
    fill_in "Título", with: "Título sin guardar"

    dismiss_confirm("Hay cambios sin guardar en esta página. Si continúas, se perderán. ¿Continuar?") do
      within("#detalles") { click_on "Bajar el detalle 1 un puesto" }
    end

    assert_field "Título", with: "Título sin guardar"
    assert_equal [ artwork_details(:collage_first), artwork_details(:collage_second) ], artworks(:collage).details.to_a
  end
end
