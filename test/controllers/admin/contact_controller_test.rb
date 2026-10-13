require "test_helper"

class Admin::ContactControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:one)
    @site = sites(:main)
  end

  test "the Contacto page shows its own fields only" do
    get edit_admin_contact_path

    assert_response :success
    assert_select "h1", "Contacto"
    assert_select ".admin-nav a[aria-current=page]", "Contacto"
    assert_select ".page-header a[href=?][target=_blank]", contact_path
    assert_select "input#site_contact_headline[value=?]", "Escríbeme"
    assert_select "input[type=email]#site_email[value=?]", "hola@example.com"
    assert_select "label[for=site_instagram_handle]", "Usuario de Instagram"
    assert_select "#site_instagram_handle_hint", "Sin @; también puedes pegar el enlace del perfil. Si lo dejas vacío, no sale."
    assert_select "input#site_instagram_handle[value=?]", "atesoraroseta"
    assert_select ".instagram-link a[href=?]", "https://www.instagram.com/atesoraroseta/"
    assert_select "label[for=site_instagram_label]", "Etiqueta «Instagram» (obligatorio)"
    assert_select "#site_wordmark, #site_about_lead", count: 0
  end

  test "saving Contacto, with a pasted Instagram profile address" do
    patch admin_contact_path, params: { site: {
      contact_headline: "Hablemos", email: " taller@example.com ",
      instagram_handle: "https://www.instagram.com/Otra.Cuenta/?igsh=abc123", instagram_label: "En Instagram"
    } }

    assert_redirected_to edit_admin_contact_path
    assert_equal "Cambios guardados.", flash[:notice]
    @site.reload
    assert_equal [ "Hablemos", "taller@example.com", "otra.cuenta", "En Instagram" ],
      [ @site.contact_headline, @site.email, @site.instagram_handle, @site.instagram_label ]
  end

  test "an @handle is stored without the @" do
    patch admin_contact_path, params: { site: { instagram_handle: "@usuario_nuevo" } }

    assert_equal "usuario_nuevo", @site.reload.instagram_handle
  end

  test "an empty email and Instagram are cleared" do
    patch admin_contact_path, params: { site: { email: "", instagram_handle: "" } }

    @site.reload
    assert_nil @site.email
    assert_nil @site.instagram_handle
  end

  test "a wrong email and a blank label are refused in Spanish" do
    patch admin_contact_path, params: { site: { email: "no es un correo", instagram_label: "" } }

    assert_response :unprocessable_content
    assert_select ".error-summary" do
      assert_select "a[href='#site_email']", "Correo electrónico no es válido"
      assert_select "a[href='#site_instagram_label']", "Etiqueta «Instagram» no puede estar en blanco"
    end
    assert_select "input#site_email[aria-invalid=true][value=?]", "no es un correo"
    assert_select ".instagram-link", count: 0
    assert_equal "hola@example.com", @site.reload.email
  end

  test "Contacto ignores the other pages' fields" do
    patch admin_contact_path, params: { site: { contact_headline: "Hola", about_lead: "Otra frase", nav_work_label: "Trabajos" } }

    @site.reload
    assert_equal "Hola", @site.contact_headline
    assert_equal Site::DEFAULTS["about_lead"], @site.about_lead
    assert_equal "Obra", @site.nav_work_label
  end
end
