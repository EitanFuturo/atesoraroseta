require "test_helper"

class Admin::ArtworksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include ActiveJob::TestHelper

  setup { sign_in_as users(:one) }

  # The list -----------------------------------------------------------------------------------------

  test "the list shows every work in the public order, with its status and warnings" do
    get admin_artworks_path

    assert_response :success
    assert_select "title", "Obras — Panel de atesoraroseta"
    assert_select "h1", "Obras"
    assert_select ".admin-nav a[aria-current=page]", "Obras"
    assert_select "a[href=?]", new_admin_artwork_path, text: "Nueva obra"
    assert_equal [ "Collage de prueba", "Obra con periodo", "Obra sin publicar", "Obra sin datos" ],
      css_select("tbody .records__title").map(&:text)

    assert_select "##{dom_id(artworks(:collage))}" do
      assert_select ".badge--published", "Publicada"
      assert_select ".records__facts", "2024 · 2 detalles"
      assert_select ".warning", text: "Imagen pequeña" # obra-01.webp is 1179 × 1571
      assert_select ".warning", text: "1 detalle sin texto alternativo"
      assert_select "a[href=?]", edit_admin_artwork_path(artworks(:collage)), text: "Editar"
      assert_select "a[href=?][target=_blank]", artwork_path(artworks(:collage)), text: /Ver en la web/
    end

    assert_select "##{dom_id(artworks(:range))}" do
      assert_select ".records__facts", "2022–2023"
      assert_select ".warning", text: "Falta el texto alternativo"
    end

    assert_select "##{dom_id(artworks(:draft))}" do
      assert_select ".badge--draft", "Borrador"
      assert_select "a[href=?]", artwork_path(artworks(:draft)), text: /vista previa/
    end
  end

  test "the admin root is the list" do
    get admin_root_path

    assert_response :success
    assert_select "h1", "Obras"
  end

  test "an empty list says so" do
    Artwork.destroy_all

    get admin_artworks_path

    assert_select ".empty-state", "Todavía no hay obras."
  end

  # New and create --------------------------------------------------------------------------------------

  test "the new-work form is in Spanish, with the year hint and the rich-text editor" do
    get new_admin_artwork_path

    assert_response :success
    assert_select "h1", "Nueva obra"
    assert_select "form[novalidate][data-controller=slug][data-unsaved-changes-main]"
    assert_select "label[for=artwork_title]", "Título (obligatorio)"
    assert_select "label[for=artwork_slug]", "Dirección (URL)"
    assert_select "label[for=artwork_years]", "Año"
    assert_select "#artwork_years_hint", "Un año (2024) o un periodo (2023–2024)."
    assert_select "input#artwork_years[aria-describedby=artwork_years_hint]"
    assert_select "label[for=artwork_medium]", "Técnica"
    assert_select "label[for=artwork_dimensions]", "Medidas"
    assert_select ".rich-text lexxy-toolbar#artwork_description_toolbar + lexxy-editor#artwork_description[toolbar=artwork_description_toolbar]"
    assert_select "lexxy-toolbar#artwork_description_toolbar button[title=Negrita]"
    assert_select "lexxy-toolbar#artwork_description_toolbar button[name=highlight]", count: 0
    assert_select "lexxy-toolbar#artwork_description_toolbar button[name=image]", count: 0
    assert_select "input[type=checkbox][role=switch]#artwork_published"
    assert_select "input[type=file]#artwork_image[accept=?][data-direct-upload-url]", ImageAttachments.accept
    assert_select "label[for=artwork_image]", "Imagen (obligatorio)"
    assert_select "label[for=artwork_image_alt]", "Texto alternativo"
    assert_select "input[type=submit][value=?]", "Crear la obra"
  end

  test "creating a work with an image" do
    assert_difference -> { Artwork.count }, 1 do
      post admin_artworks_path, params: { artwork: {
        title: "Azul de invierno", slug: "azul-de-invierno", years: "2023-24", medium: "Carteles arrancados",
        dimensions: "100 × 70 cm", description: "<p>Un texto.</p>", published: "1",
        image: fixture_file_upload("obra-01.webp", "image/webp"), image_alt: "Collage azul"
      } }
    end

    artwork = Artwork.find_by!(slug: "azul-de-invierno")
    assert_redirected_to edit_admin_artwork_path(artwork)
    assert_equal "Obra «Azul de invierno» creada. Ahora puedes añadirle fotos de detalle.", flash[:notice]
    assert_equal [ 2023, 2024 ], [ artwork.year, artwork.year_end ]
    assert_equal "2023–2024", artwork.years_label
    assert artwork.published?
    assert_equal "Collage azul", artwork.image_alt
    assert_equal "Un texto.", artwork.description.to_plain_text
    assert artwork.image.attached?
    assert_equal 1179, artwork.image_width
    assert_equal 1, artwork.position, "new works go to the top"
  end

  test "creating a work from a direct upload (a signed blob id)" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "small.png")

    post admin_artworks_path, params: { artwork: { title: "Desde el navegador", image: blob.signed_id } }

    artwork = Artwork.find_by!(title: "Desde el navegador")
    assert_equal blob, artwork.image.blob
    assert_equal 800, artwork.image_width
  end

  test "a new work that is missing its title and image gets Spanish errors" do
    assert_no_difference -> { Artwork.count } do
      post admin_artworks_path, params: { artwork: { title: "", years: "hacia 2020" } }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary[autofocus]" do
      assert_select "h2", "No se ha podido guardar: hay 3 cosas que corregir"
      assert_select "a[href='#artwork_title']", "Título no puede estar en blanco"
      assert_select "a[href='#artwork_image']", "Imagen es obligatoria"
      assert_select "a[href='#artwork_years']", "Escribe un año (2024) o un periodo (2023–2024)"
    end
    assert_select "#artwork_title_error", "Título no puede estar en blanco"
    assert_select "input#artwork_title[aria-invalid=true][aria-describedby=artwork_title_error]"
    assert_select "#artwork_years[value=?]", "hacia 2020"
    assert_select "[data-unsaved-changes-dirty-value=true]"
  end

  test "a form that comes back with errors shows the slug as it was sent, not one generated from a blank title" do
    post admin_artworks_path, params: { artwork: { title: "", slug: "" } }

    assert_response :unprocessable_content
    assert_select "input#artwork_slug[data-slug-target=slug][value='']"
    assert_select "input#artwork_slug[value=obra]", count: 0
  end

  test "image fields offer a Spanish file button over the browser's own control" do
    get new_admin_artwork_path

    assert_select ".file-picker input[type=file].file-picker__input#artwork_image"
    assert_select ".file-picker .file-picker__button[aria-hidden=true]", "Elegir archivo"
    assert_select "#artwork_image_hint", "Elige un archivo: JPEG, PNG o WebP, hasta 50 MB."
  end

  test "a slug filled from the title gets -2 when it is taken" do
    post admin_artworks_path, params: { artwork: {
      title: "Collage de prueba", slug: "collage-de-prueba", image: fixture_file_upload("small.png", "image/png")
    } }

    assert_equal "collage-de-prueba-2", Artwork.order(:id).last.slug
  end

  test "a slug filled from a title with underscores gets -2 when it is taken" do
    # The slug field turns the title's underscores into hyphens, like Artwork.slug_from.
    post admin_artworks_path, params: { artwork: {
      title: "collage_de_prueba", slug: "collage-de-prueba", image: fixture_file_upload("small.png", "image/png")
    } }

    assert_equal "collage-de-prueba-2", Artwork.order(:id).last.slug
  end

  test "a slug typed by hand that is taken is refused" do
    assert_no_difference -> { Artwork.count } do
      post admin_artworks_path, params: { artwork: {
        title: "Otra obra", slug: "collage-de-prueba", image: fixture_file_upload("small.png", "image/png")
      } }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary a[href='#artwork_slug']", "Dirección (URL) ya está en uso"
  end

  test "a valid image chosen in a form that comes back with errors is kept for the next try" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "small.png")

    post admin_artworks_path, params: { artwork: { title: "", image: blob.signed_id } }

    assert_response :unprocessable_content
    assert_select "input[type=hidden][name='artwork[image]'][value=?]", blob.signed_id
    assert_select ".image-current", text: /Imagen nueva, todavía sin guardar/

    post admin_artworks_path, params: { artwork: { title: "Segundo intento", image: blob.signed_id } }
    assert_equal blob, Artwork.find_by!(title: "Segundo intento").image.blob
  end

  test "an image of the wrong type is refused in Spanish and its upload deleted" do
    blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("not-an-image.txt").open, filename: "notas.txt")

    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ blob ]) do
      post admin_artworks_path, params: { artwork: { title: "Con texto", image: blob.signed_id } }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary a[href='#artwork_image']", "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)"
    assert_select "input[type=hidden][name='artwork[image]']", count: 0
  end

  # Edit and update -------------------------------------------------------------------------------------

  test "the edit page shows the image's size, its warning and the public link" do
    artwork = artworks(:collage)

    get edit_admin_artwork_path(artwork)

    assert_response :success
    assert_select "h1", "Collage de prueba"
    assert_select ".image-field .dimensions", "1179 × 1571 px"
    assert_select ".image-field .warning",
      "Imagen pequeña: 1571 px en el lado largo. Para que se vea nítida en pantallas grandes, sube al menos 1600 px."
    assert_select "#artwork_slug_hint", text: %r{http://www.example.com/obra/collage-de-prueba}
    assert_select ".page-header a[href=?][target=_blank]", artwork_path(artwork)
    assert_select "form[action=?][data-turbo-confirm]", admin_artwork_path(artwork)
    assert_select "lexxy-editor#artwork_description[value*=?]", "Texto de prueba sobre la obra"
  end

  test "a work without alt text is flagged on its page" do
    get edit_admin_artwork_path(artworks(:range))

    assert_select ".field .warning", "Falta el texto alternativo: ahora se usa el título."
  end

  test "updating a work keeps its image when no new file is chosen" do
    artwork = artworks(:collage)
    blob = artwork.image.blob

    patch admin_artwork_path(artwork), params: { artwork: { title: "Collage renombrado", years: "2023 — 2024", image: "" } }

    assert_redirected_to edit_admin_artwork_path(artwork)
    assert_equal "Cambios guardados.", flash[:notice]
    artwork.reload
    assert_equal "Collage renombrado", artwork.title
    assert_equal "collage-de-prueba", artwork.slug, "editing the title never changes the slug"
    assert_equal "2023–2024", artwork.years_label
    assert_equal blob, artwork.image.blob
  end

  test "changing the slug moves the work's address" do
    patch admin_artwork_path(artworks(:collage)), params: { artwork: { slug: "collage-nuevo" } }

    assert_redirected_to edit_admin_artwork_path("collage-nuevo")
    assert_equal "collage-nuevo", artworks(:collage).reload.slug
  end

  test "an invalid update renders the errors and keeps the old address in the form" do
    artwork = artworks(:collage)

    patch admin_artwork_path(artwork), params: { artwork: { slug: "Con Espacios", years: "1850" } }

    assert_response :unprocessable_content
    assert_select "form[action=?]", admin_artwork_path(artwork)
    assert_select ".error-summary li", 2
    assert_select "#artwork_years_error", "Los años deben estar entre 1900 y #{Date.current.year + 1}"
  end

  test "unpermitted parameters are ignored" do
    artwork = artworks(:collage)

    patch admin_artwork_path(artwork), params: { artwork: { title: "Nuevo título", position: 99, created_at: 1.year.ago, id: 1234 } }

    artwork.reload
    assert_equal "Nuevo título", artwork.title
    assert_equal 1, artwork.position
    assert_not_equal 1234, artwork.id
  end

  test "show sends to the edit page" do
    get admin_artwork_path(artworks(:collage))

    assert_redirected_to edit_admin_artwork_path(artworks(:collage))
  end

  test "an unknown work is a 404" do
    get edit_admin_artwork_path("no-existe")

    assert_response :not_found
  end

  # Move ----------------------------------------------------------------------------------------------

  test "moving a work one place, back to the list it came from" do
    patch move_admin_artwork_path(artworks(:range)), params: { direction: "up" }, headers: { "Referer" => admin_root_url }

    assert_redirected_to admin_root_url
    assert_equal "«Obra con periodo» ha subido un puesto.", flash[:notice]
    assert_equal %w[obra-con-periodo collage-de-prueba obra-sin-publicar obra-sin-datos], Artwork.ordered.pluck(:slug)
  end

  test "after moving down, that arrow has the focus again" do
    patch move_admin_artwork_path(artworks(:collage)), params: { direction: "down" }

    assert_redirected_to admin_artworks_path
    assert_equal "«Collage de prueba» ha bajado un puesto.", flash[:notice]
    follow_redirect!
    assert_select "##{dom_id(artworks(:collage))} button[autofocus]", text: "↓Bajar «Collage de prueba» un puesto"
    assert_select "meta[name=turbo-refresh-method][content=morph]"
    assert_select "meta[name=turbo-refresh-scroll][content=preserve]"
  end

  test "the first work can't go up and the last one can't go down" do
    get admin_artworks_path

    assert_select "##{dom_id(artworks(:collage))} button[disabled]", text: "↑Subir «Collage de prueba» un puesto"
    assert_select "##{dom_id(artworks(:bare))} button[disabled]", text: "↓Bajar «Obra sin datos» un puesto"
    assert_select "##{dom_id(artworks(:range))} button[disabled]", count: 0
  end

  test "moving the first work up changes nothing" do
    patch move_admin_artwork_path(artworks(:collage)), params: { direction: "up" }

    assert_equal %w[collage-de-prueba obra-con-periodo obra-sin-publicar obra-sin-datos], Artwork.ordered.pluck(:slug)
  end

  # Destroy -------------------------------------------------------------------------------------------

  test "deleting a work deletes its details too" do
    artwork = artworks(:collage)

    assert_difference -> { Artwork.count } => -1, -> { ArtworkDetail.count } => -2 do
      delete admin_artwork_path(artwork)
    end

    assert_redirected_to admin_artworks_path
    assert_equal "Obra «Collage de prueba» eliminada.", flash[:notice]
  end
end
