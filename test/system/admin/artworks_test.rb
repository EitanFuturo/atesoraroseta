require_relative "../admin_system_test_case"

class Admin::ArtworksTest < AdminSystemTestCase
  test "creating a work with an image, alt text and the published switch" do
    visit admin_artworks_path
    click_on "Nueva obra"

    fill_in "Título", with: "Azul de invierno"
    assert_field "Dirección (URL)", with: "azul-de-invierno"
    fill_in "Año", with: "2024"
    fill_in "Técnica", with: "Carteles arrancados sobre papel"
    fill_in "Medidas", with: "100 × 70 cm"
    assert_rich_text_editor "artwork_description"
    fill_in_rich_text "artwork_description", with: "Un texto corto sobre la obra."
    check "Publicada"
    attach_file "Imagen", file_fixture("obra-01.webp"), make_visible: true
    assert_selector ".uploads li .uploads__name", text: "obra-01.webp"
    assert_selector ".uploads li .uploads__status", text: "Lista para subir"
    fill_in "Texto alternativo", with: "Collage en azules y ocres"
    click_on "Crear la obra"

    assert_text "Obra «Azul de invierno» creada."
    assert_selector "h1", text: "Azul de invierno"
    assert_selector ".image-field .dimensions", text: "1179 × 1571 px"

    artwork = Artwork.find_by!(slug: "azul-de-invierno")
    assert artwork.published?
    assert_equal "Collage en azules y ocres", artwork.image_alt
    assert_equal "Carteles arrancados sobre papel", artwork.medium
    assert_equal "Un texto corto sobre la obra.", artwork.description.to_plain_text
    assert_not_includes artwork.description.body.to_html, "style="
    assert_equal "obra-01.webp", artwork.image.filename.to_s
    assert_no_browser_errors
  end

  test "typing 2023-24 as the year saves 2023–2024" do
    artwork = artworks(:collage)
    visit edit_admin_artwork_path(artwork)

    fill_in "Año", with: "2023-24"
    within("#artwork-form") { click_on "Guardar cambios" }

    assert_text "Cambios guardados."
    assert_field "Año", with: "2023–2024"
    artwork.reload
    assert_equal [ 2023, 2024 ], [ artwork.year, artwork.year_end ]
  end

  test "a wrong year is explained in Spanish" do
    visit edit_admin_artwork_path(artworks(:collage))

    fill_in "Año", with: "hacia 2020"
    within("#artwork-form") { click_on "Guardar cambios" }

    assert_selector ".error-summary", text: "Escribe un año (2024) o un periodo (2023–2024)"
    assert_selector "#artwork_years_error", text: "Escribe un año (2024) o un periodo (2023–2024)"
  end

  test "a file that isn't an image is refused in Spanish before uploading" do
    visit new_admin_artwork_path

    attach_file "Imagen", file_fixture("not-an-image.txt"), make_visible: true

    assert_selector ".upload-errors", text: "«not-an-image.txt» no es una imagen JPEG, PNG o WebP: no se subirá."
    assert_no_selector ".uploads li"
    assert_equal 0, page.evaluate_script("document.getElementById('artwork_image').files.length")
  end

  test "a file over 25 MB is refused before uploading" do
    path = renamed_fixture_file("small.png", "enorme.png")
    File.truncate(path, 26.megabytes)
    visit new_admin_artwork_path

    attach_file "Imagen", path, make_visible: true

    assert_selector ".upload-errors", text: "«enorme.png» pesa 26 MB y el máximo es 25 MB: no se subirá."
    assert_equal 0, page.evaluate_script("document.getElementById('artwork_image').files.length")
  end

  test "a file the server can't take shows its Spanish error" do
    # No type the browser knows, so only the server can tell it isn't an image.
    path = renamed_fixture_file("not-an-image.txt", "dibujo.xyz")
    visit new_admin_artwork_path

    fill_in "Título", with: "Obra con archivo raro"
    attach_file "Imagen", path, make_visible: true
    click_on "Crear la obra"

    assert_selector ".error-summary", text: "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)"
    assert_field "Título", with: "Obra con archivo raro"
    assert_not Artwork.exists?(title: "Obra con archivo raro")
  end

  test "deleting a work asks first" do
    visit edit_admin_artwork_path(artworks(:bare))

    accept_confirm("¿Eliminar «Obra sin datos» y todas sus fotos? No se puede deshacer.") do
      click_on "Eliminar la obra"
    end

    assert_text "Obra «Obra sin datos» eliminada."
    assert_not Artwork.exists?(artworks(:bare).id)
  end
end
