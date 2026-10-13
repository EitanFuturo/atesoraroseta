require "test_helper"

class SiteTest < ActiveSupport::TestCase
  test "the fixture is valid" do
    assert sites(:main).valid?, sites(:main).errors.full_messages.to_sentence
  end

  test "current is the stored record" do
    assert_equal sites(:main), Site.current
  end

  test "current without a row is an unsaved record with the defaults, and writes nothing" do
    Site.delete_all

    assert_no_difference -> { Site.count } do
      site = Site.current

      assert site.new_record?
      assert_equal "atesoraroseta", site.wordmark
      assert_equal "Obra", site.nav_work_label
      assert_equal "Ver los %{count} detalles", site.view_details_label
      assert_nil site.email
      assert_nil site.instagram_handle
      assert_not site.portrait.attached?
      assert site.about_body.blank?
    end
  end

  test "first_or_create! creates the row with the defaults" do
    Site.delete_all
    site = Site.first_or_create!

    assert site.persisted?
    Site::DEFAULTS.each do |column, value|
      if value.present?
        assert_equal value, site.public_send(column), column
      else
        assert_nil site.public_send(column), column
      end
    end
  end

  test "the defaults are the production texts, never placeholders" do
    assert_equal "Fotografías de carteles arrancados que inspiran la obra.", Site::DEFAULTS["torn_posters_intro"]
    assert_equal Site::DEFAULTS["about_lead"], Site::DEFAULTS["seo_description"]
    Site::DEFAULTS.each { |column, value| assert_not_includes value, "[", column }
  end

  test "there is only one settings record" do
    site = Site.new

    assert_not site.valid?
    assert_includes site.errors.full_messages, "Los ajustes del sitio ya existen"
  end

  test "labels that would leave an empty link or heading are required" do
    site = sites(:main)
    Site::REQUIRED_TEXTS.each { |column| site.public_send("#{column}=", "  ") }

    assert_not site.valid?
    assert_includes site.errors.full_messages, "Menú: Obra no puede estar en blanco"
    assert_includes site.errors.full_messages, "Nombre (logotipo) no puede estar en blanco"
    assert_equal Site::REQUIRED_TEXTS.size, site.errors.size
  end

  test "content texts may be blank" do
    site = sites(:main)
    site.assign_attributes(torn_posters_intro: "", seo_description: "", about_lead: "", contact_headline: "",
      email: "", instagram_handle: "", portrait_alt: "", not_found_text: "")

    assert site.valid?, site.errors.full_messages.to_sentence
  end

  test "normalises the Instagram handle" do
    {
      "usuario" => "usuario",
      "@usuario" => "usuario",
      "  @Usuario  " => "usuario",
      "https://www.instagram.com/usuario/" => "usuario",
      "https://instagram.com/usuario?igsh=MWQ1ZGUxMzBkMA==" => "usuario",
      "instagram.com/usuario" => "usuario",
      "http://m.instagram.com/usuario/reels/" => "usuario",
      "https://www.instagram.com/@usuario" => "usuario",
      "taller.de_rosa" => "taller.de_rosa"
    }.each do |input, handle|
      assert_equal handle, Site.new(instagram_handle: input).instagram_handle, input.inspect
    end

    assert_nil Site.new(instagram_handle: "").instagram_handle
    assert_nil Site.new(instagram_handle: " @ ").instagram_handle
  end

  test "rejects an Instagram handle with other characters" do
    site = sites(:main)
    site.instagram_handle = "mi usuario"

    assert_not site.valid?
    assert_includes site.errors.full_messages, "Usuario de Instagram no es válido"
  end

  test "Instagram helpers" do
    site = sites(:main)

    assert_equal "https://www.instagram.com/atesoraroseta/", site.instagram_url
    assert_equal "@atesoraroseta", site.instagram_at_handle

    site.instagram_handle = ""
    assert_nil site.instagram_url
    assert_nil site.instagram_at_handle
  end

  test "checks the email format, and allows a blank one" do
    site = sites(:main)

    site.email = "  hola@example.com "
    assert_equal "hola@example.com", site.email
    assert site.valid?

    site.email = "hola en example.com"
    assert_not site.valid?
    assert_includes site.errors.full_messages, "Correo electrónico no es válido"

    site.email = ""
    assert_nil site.email
    assert site.valid?
  end

  test "view_details_text uses the one-detail label for exactly one" do
    site = sites(:main)

    assert_equal "Ver el detalle", site.view_details_text(1)
    assert_equal "Ver los 8 detalles", site.view_details_text(8)

    site.view_details_label = "Detalles (%{count})"
    assert_equal "Detalles (2)", site.view_details_text(2)
    site.view_details_label = "Ver detalles"
    assert_equal "Ver detalles", site.view_details_text(2), "a label without %{count} is used as it is"
  end

  test "the portrait alt text is decorative when blank, and flagged" do
    site = sites(:main)
    assert_equal "Retrato de prueba de la artista en el taller", site.portrait_alt_text
    assert_not site.portrait_alt_missing?

    site.portrait_alt = ""
    assert_equal "", site.portrait_alt_text
    assert site.portrait_alt_missing?
  end

  test "strips surrounding spaces from texts" do
    site = sites(:main)
    site.nav_work_label = "  Obra  "

    assert_equal "Obra", site.nav_work_label
  end
end
