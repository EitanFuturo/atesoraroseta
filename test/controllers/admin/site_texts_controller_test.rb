require "test_helper"

class Admin::SiteTextsControllerTest < ActionDispatch::IntegrationTest
  FIELDS = %i[
    wordmark nav_work_label nav_torn_posters_label nav_about_label nav_contact_label torn_posters_intro
    details_label previous_label next_label view_details_label view_detail_one_label year_label medium_label dimensions_label
    seo_description not_found_title not_found_text not_found_link_label
  ].freeze

  setup do
    sign_in_as users(:one)
    @site = sites(:main)
  end

  test "the page groups every site text in fieldsets" do
    get edit_admin_site_texts_path

    assert_response :success
    assert_select "h1", "Textos del sitio"
    assert_select ".admin-nav a[aria-current=page]", "Textos del sitio"
    assert_select ".page-header a[href='/'][target=_blank]"
    assert_equal [ "Cabecera y menú", "Torn Posters", "Página de cada obra", "Buscadores y redes sociales", "Icono del sitio", "Página no encontrada" ],
      css_select("fieldset legend").map(&:text)
    FIELDS.each { |field| assert_select "#site_#{field}", 1 }
    assert_select "input#site_wordmark[value=atesoraroseta]"
    assert_select "label[for=site_wordmark]", "Nombre (logotipo) (obligatorio)"
    assert_select "input#site_view_details_label[value=?]", "Ver los %{count} detalles"
    assert_select "#site_view_details_label_hint", /Escribe %\{count\} donde va el número/
    assert_select "label[for=site_seo_description]", "Descripción para buscadores"
    assert_select "input[type=file]#site_og_image[accept=?]", ImageAttachments.accept
    assert_select "input[type=file]#site_favicon"
    assert_select "#site_about_lead, #site_email", count: 0
  end

  test "saving the texts" do
    patch admin_site_texts_path, params: { site: {
      wordmark: "atesoraroseta", nav_work_label: "Trabajos", view_details_label: "Ver sus %{count} detalles",
      torn_posters_intro: "", seo_description: "Collages de carteles arrancados.", not_found_title: "No está"
    } }

    assert_redirected_to edit_admin_site_texts_path
    assert_equal "Cambios guardados.", flash[:notice]
    @site.reload
    assert_equal "Trabajos", @site.nav_work_label
    assert_equal "Ver sus 8 detalles", @site.view_details_text(8)
    assert_equal "", @site.torn_posters_intro.to_s
    assert_equal "Collages de carteles arrancados.", @site.seo_description
    assert_equal "No está", @site.not_found_title
  end

  test "required texts left blank are refused in Spanish and nothing is saved" do
    patch admin_site_texts_path, params: { site: { wordmark: "", next_label: " ", nav_work_label: "Trabajos" } }

    assert_response :unprocessable_content
    assert_select ".error-summary" do
      assert_select "h2", "No se ha podido guardar: hay 2 cosas que corregir"
      assert_select "a[href='#site_wordmark']", "Nombre (logotipo) no puede estar en blanco"
      assert_select "a[href='#site_next_label']", "Etiqueta «Siguiente» no puede estar en blanco"
    end
    assert_select "input#site_nav_work_label[value=Trabajos]"
    assert_equal "Obra", @site.reload.nav_work_label
  end

  test "the social image and the favicon have their own size checks" do
    patch admin_site_texts_path, params: { site: {
      og_image: fixture_file_upload("small.png", "image/png"), favicon: fixture_file_upload("small.png", "image/png")
    } }

    assert_redirected_to edit_admin_site_texts_path
    follow_redirect!
    assert_select ".image-field .warning", "Imagen pequeña para compartir: 800 × 600 px. Se ve mejor de al menos 1200 × 630 px."
    assert_select ".image-field .warning", "El icono no es cuadrado (800 × 600 px): se usará su parte central."
    assert_select ".image-field .warning", text: /lado largo/, count: 0
  end

  test "removing the social image" do
    @site.og_image.attach(fixture_attachable("small.png"))

    patch admin_site_texts_path, params: { site: { wordmark: "atesoraroseta", remove_og_image: "1" } }

    assert_redirected_to edit_admin_site_texts_path
    assert_not @site.reload.og_image.attached?
  end

  test "the texts page ignores the other pages' fields" do
    patch admin_site_texts_path, params: { site: { wordmark: "atesoraroseta", email: "otro@example.com", portrait_alt: "Otro" } }

    @site.reload
    assert_equal "hola@example.com", @site.email
    assert_equal "Retrato de prueba de la artista en el taller", @site.portrait_alt
  end
end
