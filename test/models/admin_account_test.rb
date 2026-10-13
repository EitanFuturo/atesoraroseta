require "test_helper"

# Credentials and the environment are plain hashes here: the real credentials are never read.
class AdminAccountTest < ActiveSupport::TestCase
  PASSWORD = "contraseña-de-prueba-1"
  NEW_PASSWORD = "otra-contraseña-de-prueba"
  SHORT_PASSWORD = "abc123"

  def credentials(email: "admin@atesoraroseta.com", password: PASSWORD)
    { admin: { email: email, password: password }.compact }
  end

  def sync(credentials: self.credentials, env: {})
    AdminAccount.sync(credentials: credentials, env: env)
  end

  test "creates the admin from the credentials" do
    result = assert_difference(-> { User.count }, 1) { sync }

    assert_equal :created, result.status
    assert_equal "Admin: usuario admin@atesoraroseta.com creado.", result.message
    assert User.find_by(email_address: "admin@atesoraroseta.com").authenticate(PASSWORD)
  end

  test "the environment overrides the credentials" do
    sync(env: { "ADMIN_EMAIL" => "ci@example.com", "ADMIN_PASSWORD" => NEW_PASSWORD })

    assert User.find_by(email_address: "ci@example.com").authenticate(NEW_PASSWORD)
    assert_nil User.find_by(email_address: "admin@atesoraroseta.com")
  end

  test "each value can come from either source" do
    sync(env: { "ADMIN_PASSWORD" => NEW_PASSWORD, "ADMIN_EMAIL" => "" })

    assert User.find_by(email_address: "admin@atesoraroseta.com").authenticate(NEW_PASSWORD)
  end

  test "normalises the email" do
    sync(credentials: credentials(email: "  Admin@Atesoraroseta.COM "))
    result = sync

    assert_equal :unchanged, result.status
    assert_equal 1, User.where(email_address: "admin@atesoraroseta.com").count
  end

  test "leaves an unchanged password alone, sessions included" do
    sync
    user = User.find_by(email_address: "admin@atesoraroseta.com")
    user.sessions.create!

    result = assert_no_difference(-> { Session.count }) { sync }

    assert_equal :unchanged, result.status
    assert_equal "Admin: admin@atesoraroseta.com sin cambios.", result.message
  end

  test "changes the password and closes all of that user's sessions" do
    sync
    user = User.find_by(email_address: "admin@atesoraroseta.com")
    2.times { user.sessions.create! }
    other_session = users(:one).sessions.create!

    result = sync(credentials: credentials(password: NEW_PASSWORD))

    assert_equal :updated, result.status
    assert_equal "Admin: contraseña de admin@atesoraroseta.com actualizada; 2 sesiones cerradas.", result.message
    assert user.reload.authenticate(NEW_PASSWORD)
    assert_not user.authenticate(PASSWORD)
    assert_empty user.sessions
    assert Session.exists?(other_session.id), "other users keep their sessions"
  end

  test "without an email or a password it warns and does nothing" do
    [
      [ {}, "el correo (admin.email o ADMIN_EMAIL) y la contraseña (admin.password o ADMIN_PASSWORD)" ],
      [ credentials(password: nil), "la contraseña (admin.password o ADMIN_PASSWORD)" ],
      [ credentials(email: ""), "el correo (admin.email o ADMIN_EMAIL)" ]
    ].each do |source, missing|
      result = assert_no_difference(-> { User.count }) { sync(credentials: source) }

      assert_equal :skipped, result.status
      assert result.warning?
      assert_equal "Admin: falta #{missing}; no se crea ni se cambia ningún usuario.", result.message
    end
  end

  test "credentials that can't be read are skipped with a note" do
    unreadable = Object.new
    def unreadable.dig(*) = raise(ActiveSupport::MessageEncryptor::InvalidMessage)

    result = sync(credentials: unreadable)

    assert_equal :skipped, result.status
    assert_includes result.message, "No se pudieron leer las credenciales (ActiveSupport::MessageEncryptor::InvalidMessage)."
  end

  test "a password under 12 characters is refused without changing anything" do
    result = assert_no_difference(-> { User.count }) { sync(credentials: credentials(password: SHORT_PASSWORD)) }
    assert_equal :invalid, result.status
    assert result.warning?
    assert_equal "Admin: no se ha guardado admin@atesoraroseta.com: Contraseña es demasiado corta (12 caracteres mínimo).", result.message

    sync
    user = User.find_by(email_address: "admin@atesoraroseta.com")
    session = user.sessions.create!
    assert_equal :invalid, sync(credentials: credentials(password: SHORT_PASSWORD)).status
    assert user.reload.authenticate(PASSWORD)
    assert Session.exists?(session.id)
  end

  test "messages never contain the password" do
    results = [ sync, sync(credentials: credentials(password: NEW_PASSWORD)), sync(credentials: credentials(password: SHORT_PASSWORD)) ]

    results.each do |result|
      assert_not_includes result.message, PASSWORD
      assert_not_includes result.message, NEW_PASSWORD
      assert_not_includes result.message, SHORT_PASSWORD
    end
  end
end
