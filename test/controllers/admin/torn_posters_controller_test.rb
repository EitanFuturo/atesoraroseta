require "test_helper"

class Admin::TornPostersControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:one)
    @street, @wall, @draft = torn_posters(:street), torn_posters(:wall), torn_posters(:draft)
  end

  # The table -------------------------------------------------------------------------------------------

  test "the table lists every photo in the public order, each with its fields" do
    get admin_torn_posters_path

    assert_response :success
    assert_select "title", "Torn Posters — Panel de atesoraroseta"
    assert_select ".admin-nav a[aria-current=page]", "Torn Posters"
    assert_equal [ @street, @wall, @draft ].map { |poster| dom_id(poster) }, css_select("tbody tr").map { |row| row["id"] }
    assert_select "form#posters-form[action=?]", bulk_update_admin_torn_posters_path do
      assert_select "input[type=submit][value=?]", "Guardar cambios", count: 2
      assert_select "button[type=submit][name=publish_all][value='1']", "Marcar todas como publicadas"
    end

    assert_select "##{dom_id(@street)}" do
      assert_select "input[name='torn_posters[#{@street.id}][place]'][value=?]", "Calle de Toledo"
      assert_select "label[for=torn_posters_#{@street.id}_place]", "Lugar de la foto 1"
      assert_select "input[name='torn_posters[#{@street.id}][city]'][value=?]", "Madrid"
      assert_select "input[name='torn_posters[#{@street.id}][years]'][value=?]", "2024"
      assert_select "input[name='torn_posters[#{@street.id}][alt]']"
      assert_select ".warning", text: "Falta el texto alternativo: ahora se usa «Calle de Toledo, Madrid»."
      assert_select "input[type=checkbox][name='torn_posters[#{@street.id}][published]'][checked]"
      assert_select ".warning", text: "Imagen pequeña"
      assert_select "button[form=?][disabled]", "#{dom_id(@street, :move)}-up"
      assert_select "button[form=?]:not([disabled])", "#{dom_id(@street, :move)}-down"
      assert_select "a[href=?]", edit_admin_torn_poster_path(@street), text: "Cambiar la imagen de la foto 1"
      assert_select "a[href=?][target=_blank]", "/torn-posters#poster-#{@street.id}", text: /Ver en la web/
      assert_select "button[form=?][data-turbo-confirm=?]", dom_id(@street, :destroy), "¿Eliminar la foto 1? No se puede deshacer."
    end
    assert_select "##{dom_id(@wall)} input[name='torn_posters[#{@wall.id}][years]'][value=?]", "2019–2020"
    assert_select "##{dom_id(@draft)} .view-on-site--unpublished", "Ver en la web (sin publicar)"
    assert_select "##{dom_id(@draft)} a[href*=poster-]", count: 0

    # The forms behind the row buttons sit outside the table's form.
    assert_select "form#posters-form form", count: 0
    assert_select "form##{dom_id(@street, :move)}-down[hidden][action=?] input[name=direction][value=down]", move_admin_torn_poster_path(@street)
    assert_select "form##{dom_id(@street, :destroy)}[hidden][action=?]", admin_torn_poster_path(@street)
  end

  # Uploading ------------------------------------------------------------------------------------------

  test "uploading several photos adds them unpublished at the top, the first file first" do
    blobs = %w[primera segunda tercera].map do |name|
      ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "#{name}.png")
    end

    assert_difference -> { TornPoster.count }, 3 do
      post admin_torn_posters_path, params: { images: [ "", *blobs.map(&:signed_id) ] }
    end

    assert_redirected_to admin_torn_posters_path
    assert_equal "Se han subido 3 fotos. Están sin publicar: revisa sus datos y publícalas.", flash[:notice]
    posters = TornPoster.ordered.to_a
    assert_equal %w[primera.png segunda.png tercera.png], posters.first(3).map { |poster| poster.image.filename.to_s }
    assert_equal [ @street, @wall, @draft ], posters.last(3)
    assert posters.first(3).none?(&:published?)
    assert_equal (1..6).to_a, posters.map(&:position)
  end

  test "a refused file is listed in Spanish and the others are uploaded" do
    good = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "buena.png")
    text = ActiveStorage::Blob.create_and_upload!(io: file_fixture("not-an-image.txt").open, filename: "lista.txt")

    assert_difference -> { TornPoster.count }, 1 do
      post admin_torn_posters_path, params: { images: [ text.signed_id, good.signed_id ] }
    end

    assert_equal "Se ha subido 1 foto. Está sin publicar: revisa sus datos y publícala.", flash[:notice]
    assert_equal "No se ha podido subir 1 archivo:", flash[:alert]
    assert_equal [ "«lista.txt»: Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)" ], flash[:alert_details]
    assert_enqueued_with(job: ActiveStorage::PurgeJob, args: [ text ])
  end

  test "uploading nothing says so" do
    post admin_torn_posters_path, params: { images: [ "" ] }

    assert_redirected_to admin_torn_posters_path
    assert_equal "Elige al menos una foto para subir.", flash[:alert]
  end

  # Saving the table ----------------------------------------------------------------------------------------

  test "saving the table updates every row" do
    patch bulk_update_admin_torn_posters_path, params: { torn_posters: {
      @street.id => { place: "Plaza Mayor", city: "Madrid", years: "2023-24", alt: "Cartel rojo y negro", published: "0" },
      @wall.id => { place: "", city: "Lisboa", years: "2019–2020", alt: "Cartel arrancado en rojos y negros", published: "1" }
    } }

    assert_redirected_to admin_torn_posters_path
    assert_equal "Cambios guardados.", flash[:notice]
    @street.reload
    assert_equal [ "Plaza Mayor", "Madrid", 2023, 2024, "Cartel rojo y negro", false ],
      [ @street.place, @street.city, @street.year, @street.year_end, @street.alt, @street.published ]
    assert @wall.reload.published?
  end

  test "a wrong year in one row saves nothing, keeps what was typed and points at the row in Spanish" do
    patch bulk_update_admin_torn_posters_path, params: { torn_posters: {
      @street.id => { place: "Plaza Mayor", years: "2023-24" },
      @wall.id => { years: "hacia 2020" }
    } }

    assert_response :unprocessable_content
    assert_select ".error-summary[autofocus]" do
      assert_select "h2", "No se ha guardado nada: corrige las fotos marcadas."
      assert_select "a[href=?]", "#torn_posters_#{@wall.id}_years", text: "Foto 2: Escribe un año (2024) o un periodo (2023–2024)"
    end
    assert_select "tr##{dom_id(@wall)}.is-invalid" do
      assert_select "input#torn_posters_#{@wall.id}_years[aria-invalid=true][value=?]", "hacia 2020"
      assert_select "#torn_posters_#{@wall.id}_years_error", "Escribe un año (2024) o un periodo (2023–2024)"
    end
    assert_select "input#torn_posters_#{@street.id}_place[value=?]", "Plaza Mayor"
    assert_select "[data-unsaved-changes-dirty-value=true]"
    assert_equal "Calle de Toledo", @street.reload.place
  end

  test "marking every photo as published saves the table too" do
    patch bulk_update_admin_torn_posters_path, params: { publish_all: "1", torn_posters: {
      @draft.id => { place: "Mercado de Colón", published: "0" }
    } }

    assert_redirected_to admin_torn_posters_path
    assert_equal "Cambios guardados. Todas las fotos están publicadas.", flash[:notice]
    assert TornPoster.all.all?(&:published?)
    assert_equal "Mercado de Colón", @draft.reload.place
  end

  test "the table ignores unpermitted fields and unknown rows" do
    patch bulk_update_admin_torn_posters_path, params: { torn_posters: {
      @street.id => { place: "Plaza Mayor", position: 99, created_at: 1.year.ago },
      "999999" => { place: "Nadie" }
    } }

    assert_redirected_to admin_torn_posters_path
    @street.reload
    assert_equal "Plaza Mayor", @street.place
    assert_equal 1, @street.position
  end

  # Moving and deleting ------------------------------------------------------------------------------------

  test "moving a photo one place" do
    patch move_admin_torn_poster_path(@street), params: { direction: "down" }

    assert_redirected_to admin_torn_posters_path
    assert_equal "La foto ha bajado un puesto.", flash[:notice]
    assert_equal [ @wall, @street, @draft ], TornPoster.ordered.to_a
    follow_redirect!
    assert_select "button[autofocus][form=?]", "#{dom_id(@street, :move)}-down"
  end

  test "deleting a photo" do
    assert_difference -> { TornPoster.count }, -1 do
      delete admin_torn_poster_path(@wall)
    end

    assert_redirected_to admin_torn_posters_path
    assert_equal "Foto eliminada.", flash[:notice]
    assert_equal [ 1, 2 ], TornPoster.ordered.pluck(:position)
  end

  # A photo's own page --------------------------------------------------------------------------------------

  test "a photo's page shows its image and fields" do
    get edit_admin_torn_poster_path(@street)

    assert_response :success
    assert_select "h1", "Foto: Calle de Toledo, Madrid"
    assert_select ".image-field .dimensions", "800 × 600 px"
    assert_select ".image-field .warning", /Imagen pequeña: 800 px en el lado largo/
    assert_select "input#torn_poster_years[value=?]", "2024"
    assert_select "input[type=checkbox][role=switch]#torn_poster_published"
  end

  test "replacing a photo's image" do
    patch admin_torn_poster_path(@street), params: { torn_poster: { image: fixture_file_upload("obra-01-d5.jpg", "image/jpeg"), place: "Calle de Toledo" } }

    assert_redirected_to admin_torn_posters_path(anchor: dom_id(@street))
    assert_equal "Foto guardada.", flash[:notice]
    assert_equal "obra-01-d5.jpg", @street.reload.image.filename.to_s
  end

  test "a photo's page refuses a file that isn't an image, in Spanish" do
    patch admin_torn_poster_path(@street), params: { torn_poster: { image: fixture_file_upload("not-an-image.txt", "text/plain") } }

    assert_response :unprocessable_content
    assert_select ".error-summary a[href='#torn_poster_image']", "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)"
    assert_select ".image-field .dimensions", "800 × 600 px"
    assert_equal "small.png", @street.reload.image.filename.to_s
  end

  test "show sends to the photo's page" do
    get admin_torn_poster_path(@street)

    assert_redirected_to edit_admin_torn_poster_path(@street)
  end
end
