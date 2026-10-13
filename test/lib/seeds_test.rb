require "test_helper"

# The seeds run against an empty database here (the fixtures are cleared first). Credentials and the
# environment are plain hashes, so the real credentials are never read.
class SeedsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  PASSWORD = "contraseña-de-prueba-1"

  setup do
    [ Session, User, ArtworkDetail, Artwork, TornPoster, Site, ActionText::RichText ].each(&:delete_all)
    [ ActiveStorage::Attachment, ActiveStorage::VariantRecord, ActiveStorage::Blob ].each(&:delete_all)
  end

  def run_seeds(environment, credentials: {}, env: {})
    output = StringIO.new
    Seeds.run(environment: environment, credentials: credentials, env: env, output: output, process_variants: false)
    output.string
  end

  def admin_credentials
    { admin: { email: "admin@atesoraroseta.com", password: PASSWORD } }
  end

  def site_texts(site)
    site.attributes.values.grep(String) + [ site.about_body.to_plain_text ]
  end

  test "production gets only the default site texts and the admin from the credentials" do
    output = run_seeds("production", credentials: admin_credentials)

    assert_equal [ 0, 0, 0, 1, 1 ], [ Artwork.count, ArtworkDetail.count, TornPoster.count, Site.count, User.count ]
    assert User.find_by(email_address: "admin@atesoraroseta.com").authenticate(PASSWORD)
    assert_includes output, "Ajustes del sitio: creados con los textos por defecto."
    assert_includes output, "Admin: usuario admin@atesoraroseta.com creado."
    assert_not_includes output, PASSWORD
  end

  test "production never seeds a bracketed placeholder" do
    run_seeds("production", credentials: admin_credentials)
    site = Site.sole

    site_texts(site).each { |text| assert_not_includes text, "[" }
    assert_equal "atesoraroseta", site.wordmark
    assert_nil site.email
    assert_nil site.instagram_handle
    assert site.about_body.blank?
    assert_not site.portrait.attached?
    assert_equal 0, ActiveStorage::Blob.count
  end

  test "the admin comes only from the credentials or the environment" do
    output = run_seeds("production")
    assert_equal 0, User.count
    assert_includes output, "Admin: falta el correo"

    run_seeds("production", env: { "ADMIN_EMAIL" => "ci@example.com", "ADMIN_PASSWORD" => PASSWORD })
    assert_equal [ "ci@example.com" ], User.pluck(:email_address)
  end

  test "the test environment seeds like production" do
    run_seeds("test")

    assert_equal [ 0, 0, 0, 1 ], [ Artwork.count, ArtworkDetail.count, TornPoster.count, Site.count ]
  end

  test "an existing settings row is left alone" do
    Site.create!(wordmark: "otro nombre")
    output = run_seeds("production")

    assert_equal "otro nombre", Site.sole.wordmark
    assert_includes output, "Ajustes del sitio: ya existían."
  end

  test "development gets the canvas's sample content, and a second run changes nothing" do
    run_seeds("development")

    assert_equal [ 9, 8, 12, 1 ], [ Artwork.count, ArtworkDetail.count, TornPoster.count, Site.count ]
    assert_equal %w[01 03 08 04 02 07 06 05 09].map { "obra-de-muestra-#{it}" }, Artwork.ordered.pluck(:slug)
    assert Artwork.all.all?(&:published?)
    assert TornPoster.all.all?(&:published?)

    obra = Artwork.find_by!(slug: "obra-de-muestra-01")
    assert_equal "Obra de muestra 01", obra.title
    assert_equal Seeds::SampleContent::OBRA_01_ALT, obra.image_alt
    assert_equal [ 1179, 1571 ], [ obra.image_width, obra.image_height ]
    assert_equal %w[d5 d1 d6 d8 d3 d2 d4 d7].map { "obra-01-#{it}.jpg" }, obra.details.map { it.image.filename.to_s }
    assert_equal "Detalle: papel blanco arrugado sobre azul", obra.details.first.alt
    assert_equal Seeds::SampleContent::STAND_IN_ALT, Artwork.find_by!(slug: "obra-de-muestra-02").image_alt
    assert_equal "2023–2024", Artwork.find_by!(slug: "obra-de-muestra-03").years_label

    posters = TornPoster.ordered.to_a
    assert_equal (1..12).map { format("torn-poster-%02d.jpg", it) }, posters.map { it.image.filename.to_s }
    assert_equal [ 1600, 1600 ], [ posters.first.image_width, posters.first.image_height ]
    assert_not posters.first.image_low_resolution?
    assert_equal "2023–2024", posters.second.years_label
    assert_equal "[Lugar], [Ciudad]", posters.first.alt_text

    site = Site.sole
    assert_equal "tu-correo@example.com", site.email
    assert_equal "usuario", site.instagram_handle
    assert_equal "[Retrato o foto en el taller]", site.portrait_alt
    assert_equal [ 1600, 2000 ], [ site.portrait_width, site.portrait_height ]
    assert_equal 2, site.about_body.body.fragment.find_all("p").size

    counts = -> { [ Artwork, ArtworkDetail, TornPoster, Site, ActiveStorage::Blob, ActionText::RichText ].map(&:count) }
    assert_no_changes counts do
      assert_no_changes -> { [ Artwork.maximum(:updated_at), Site.sole.updated_at ] } do
        output = run_seeds("development")
        assert_includes output, "Obras de muestra: 0 creadas."
        assert_includes output, "Sobre mí y Contacto: sin cambios."
      end
    end
  end

  test "development queues every preprocessed variant" do
    assert_enqueued_jobs 9 * 4 + 8 * 3 + 12 * 3 + 3, only: ActiveStorage::TransformJob do
      run_seeds("development")
    end
  end

  test "development keeps what the admin already changed" do
    Site.create!(email: "artista@example.com")
    run_seeds("development")

    assert_equal "artista@example.com", Site.sole.email
    assert_equal "usuario", Site.sole.instagram_handle
  end
end
