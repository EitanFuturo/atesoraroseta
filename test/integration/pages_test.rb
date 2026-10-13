require "test_helper"

# Sobre mí and Contacto, built from the settings record (sites(:main): an email, an Instagram handle, an
# about body of two paragraphs and a portrait with alt text).
class PagesTest < ActionDispatch::IntegrationTest
  test "Sobre mí: the portrait, the heading, the lead, the body and the link to Contacto" do
    get "/sobre-mi"
    assert_response :success

    assert_select "main.main-about .about" do
      assert_select "figure.about-portrait img.about-portrait-img[alt='Retrato de prueba de la artista en el taller']"
      assert_select ".about-text" do
        assert_select "h1.label.page-label", "Sobre mí"
        assert_select "p.about-lead", Site::DEFAULTS.fetch("about_lead")
        assert_select ".about-body.rich-text .lexxy-content p", 2
        assert_select "a.text-link.standalone-link[href='/contacto']", "Escríbeme"
      end
    end
  end

  test "the portrait uses the 4:5 crops, loads eagerly with high priority, and is at most 540px wide" do
    get "/sobre-mi"
    image = css_select("img.about-portrait-img").first
    portrait = sites(:main).portrait

    assert_equal "#{rails_storage_proxy_path(portrait.variant(:portrait_600))} 336w", image["srcset"]
    assert_equal "high", image["fetchpriority"]
    assert_nil image["loading"]
    assert_equal "(min-width: 1399px) 540px, (min-width: 894px) calc(42.2vw - 50px), (min-width: 593px) 540px, 91.1vw",
      image["sizes"]
  end

  test "Sobre mí leaves out a missing portrait, lead and body" do
    site = sites(:main)
    site.portrait.purge
    site.update!(about_lead: "", about_body: "")

    get "/sobre-mi"
    assert_select "figure.about-portrait", 0
    assert_select "p.about-lead", 0
    assert_select ".about-body", 0
    assert_select "h1", "Sobre mí"
    assert_select "a.standalone-link", "Escríbeme"
  end

  test "a portrait without alt text is decorative" do
    sites(:main).update!(portrait_alt: "")

    get "/sobre-mi"
    assert_select "img.about-portrait-img[alt='']"
  end

  test "rich text links look like text links and lose their inline styles" do
    sites(:main).update!(about_body: '<p>Ver <a href="https://example.com/expo" style="color: red">la exposición</a>.</p>')

    get "/sobre-mi"
    assert_select ".about-body a[href='https://example.com/expo']:not([style])", "la exposición"
  end

  test "Contacto: the heading, the headline, the email and the Instagram row" do
    get "/contacto"
    assert_response :success

    assert_select "main.main-contact .contact" do
      assert_select "h1.label.page-label", "Contacto"
      assert_select "p.contact-headline", "Escríbeme"
      assert_select "a.text-link.contact-email[href='mailto:hola@example.com']", "hola@example.com"
      assert_select ".contact-links .contact-link-group" do
        assert_select "span.label", "Instagram"
        assert_select "a.text-link.contact-handle[href='https://www.instagram.com/atesoraroseta/']", "@atesoraroseta"
      end
    end
  end

  test "Contacto leaves out a missing headline, email and Instagram handle" do
    sites(:main).update!(contact_headline: "", email: "", instagram_handle: "")

    get "/contacto"
    assert_select "h1", "Contacto"
    assert_select ".contact-headline", 0
    assert_select "a[href^=mailto]", 0
    assert_select ".contact-links", 0
  end
end
