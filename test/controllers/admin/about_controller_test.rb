require "test_helper"

class Admin::AboutControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    sign_in_as users(:one)
    @site = sites(:main)
  end

  test "the Sobre mí page shows its own fields only" do
    get edit_admin_about_path

    assert_response :success
    assert_select "h1", "Sobre mí"
    assert_select ".admin-nav a[aria-current=page]", "Sobre mí"
    assert_select ".page-header a[href=?][target=_blank]", about_path
    assert_select "textarea#site_about_lead", text: @site.about_lead
    assert_select "lexxy-editor#site_about_body[value*=?]", "Primer párrafo de prueba"
    assert_select "label[for=site_about_contact_link_label]", "Sobre mí: enlace a contacto (obligatorio)"
    assert_select "input#site_about_contact_link_label[value=?]", "Escríbeme"
    assert_select "label[for=site_portrait]", "Retrato"
    assert_select ".image-field .dimensions", "340 × 420 px"
    assert_select ".image-field .warning", /Imagen pequeña: 420 px en el lado largo/
    assert_select "input[type=checkbox][name='site[remove_portrait]']#site_portrait_remove"
    assert_select "input#site_portrait_alt[value=?]", @site.portrait_alt
    assert_select "#site_wordmark, #site_email", count: 0
  end

  test "saving Sobre mí" do
    patch admin_about_path, params: { site: {
      about_lead: "Recojo carteles arrancados.", about_body: "<p>Uno.</p><p>Dos.</p>",
      portrait_alt: "La artista en el taller", about_contact_link_label: "Escríbeme ya"
    } }

    assert_redirected_to edit_admin_about_path
    assert_equal "Cambios guardados.", flash[:notice]
    @site.reload
    assert_equal "Recojo carteles arrancados.", @site.about_lead
    assert_equal "Uno.\n\nDos.", @site.about_body.to_plain_text
    assert_equal "La artista en el taller", @site.portrait_alt
    assert_equal "Escríbeme ya", @site.about_contact_link_label
  end

  test "uploading a portrait" do
    patch admin_about_path, params: { site: { portrait: fixture_file_upload("obra-01.webp", "image/webp") } }

    assert_redirected_to edit_admin_about_path
    assert_equal "obra-01.webp", @site.reload.portrait.filename.to_s
    assert_equal 1179, @site.portrait_width
  end

  test "removing the portrait" do
    patch admin_about_path, params: { site: { portrait_alt: "", remove_portrait: "1" } }

    assert_redirected_to edit_admin_about_path
    assert_not @site.reload.portrait.attached?
  end

  test "a new portrait wins over removing the old one" do
    patch admin_about_path, params: { site: { remove_portrait: "1", portrait: fixture_file_upload("small.png", "image/png") } }

    assert_equal "small.png", @site.reload.portrait.filename.to_s
  end

  test "a required text left blank is refused in Spanish" do
    patch admin_about_path, params: { site: { about_lead: "Cambiado", about_contact_link_label: " " } }

    assert_response :unprocessable_content
    assert_select ".error-summary a[href='#site_about_contact_link_label']", "Sobre mí: enlace a contacto no puede estar en blanco"
    assert_select "textarea#site_about_lead", text: "Cambiado"
    assert_equal "Escríbeme", @site.reload.about_contact_link_label
  end

  test "a portrait that isn't an image is refused in Spanish" do
    patch admin_about_path, params: { site: { portrait: fixture_file_upload("not-an-image.txt", "text/plain") } }

    assert_response :unprocessable_content
    assert_select ".error-summary a[href='#site_portrait']", "Retrato tiene un formato no admitido (usa JPEG, PNG o WebP)"
    assert_equal "obra-01-d5.jpg", @site.reload.portrait.filename.to_s
  end

  test "Sobre mí ignores the other pages' fields" do
    patch admin_about_path, params: { site: { about_lead: "Nueva frase", wordmark: "otro nombre", email: "otro@example.com" } }

    @site.reload
    assert_equal "Nueva frase", @site.about_lead
    assert_equal "atesoraroseta", @site.wordmark
    assert_equal "hola@example.com", @site.email
  end

  test "the settings row is created with the defaults when it is missing" do
    Site.delete_all

    assert_difference -> { Site.count }, 1 do
      get edit_admin_about_path
    end

    assert_response :success
    assert_select "textarea#site_about_lead", text: Site::DEFAULTS["about_lead"]
  end

  test "show sends to the form" do
    get admin_about_path

    assert_redirected_to edit_admin_about_path
  end
end
