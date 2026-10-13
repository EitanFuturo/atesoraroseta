require "test_helper"

# Every test works on a temporary encrypted file with its own key; config/credentials.yml.enc is never touched.
class AdminCredentialsTest < ActiveSupport::TestCase
  PASSWORD = "contraseña-de-prueba-1"

  TEMPLATE = <<~YAML
    # aws:
    #   access_key_id: 123
    #   secret_access_key: 345

    # Used as the base secret for all MessageVerifiers in Rails, including the one protecting cookies.
    secret_key_base: 0123456789abcdef
  YAML

  def with_credentials(content = TEMPLATE)
    Dir.mktmpdir do |dir|
      key_path = File.join(dir, "master.key")
      File.write(key_path, ActiveSupport::EncryptedFile.generate_key)
      credentials = encrypted(dir, key_path)
      credentials.write(content) if content
      yield credentials, dir
    end
  end

  def encrypted(dir, key_path)
    ActiveSupport::EncryptedConfiguration.new(
      config_path: File.join(dir, "credentials.yml.enc"), key_path: key_path,
      env_key: "ADMIN_CREDENTIALS_TEST_UNUSED_KEY", raise_if_missing_key: false
    )
  end

  def reread(credentials)
    encrypted(File.dirname(credentials.content_path), credentials.key_path)
  end

  def run_task(credentials, env: {}, input: "", interactive: false)
    output = StringIO.new
    AdminCredentials.run(credentials: credentials, env: env, input: StringIO.new(input), output: output, interactive: interactive)
    output.string
  end

  test "adds the admin block and keeps the rest of the file, comments included" do
    with_credentials do |credentials|
      AdminCredentials.new(credentials: credentials).write(email: "admin@atesoraroseta.com", password: PASSWORD)
      stored = reread(credentials)

      assert_equal "admin@atesoraroseta.com", stored.dig(:admin, :email)
      assert_equal PASSWORD, stored.dig(:admin, :password)
      assert_equal "0123456789abcdef", stored.secret_key_base
      assert stored.read.start_with?(TEMPLATE), "the original text is untouched"
      assert_includes stored.read, "# Used as the base secret"
    end
  end

  test "replaces an existing admin block in place" do
    content = <<~YAML
      # Comment at the top.
      secret_key_base: 0123456789abcdef

      admin:
        email: old@example.com
        # an old note
        password: old-password-123

      # Registry token for Kamal.
      kamal:
        registry_password: token
    YAML

    with_credentials(content) do |credentials|
      AdminCredentials.new(credentials: credentials).write(email: "admin@atesoraroseta.com", password: PASSWORD)
      text = reread(credentials).read

      assert_equal 1, text.scan(/^admin:/).size
      assert_not_includes text, "old@example.com"
      assert_not_includes text, "an old note"
      assert_includes text, "# Registry token for Kamal.\nkamal:\n  registry_password: token\n"
      assert_operator text.index("admin:"), :<, text.index("kamal:"), "where it was"
      assert_equal "token", reread(credentials).dig(:kamal, :registry_password)
      assert_equal PASSWORD, reread(credentials).dig(:admin, :password)
    end
  end

  test "stores passwords with YAML's special characters exactly" do
    [ "#no es un comentario", "clave: con dos puntos", "'comillas' y \"dobles\"", "yes-yes-yes-yes", " espacio delante", "@arroba1234567" ].each do |password|
      with_credentials do |credentials|
        AdminCredentials.new(credentials: credentials).write(email: "admin@atesoraroseta.com", password: password)

        assert_equal password, reread(credentials).dig(:admin, :password)
      end
    end
  end

  test "refuses a short password, an over-long one, or a bad email, and writes nothing" do
    with_credentials do |credentials|
      before = File.binread(credentials.content_path)
      writer = AdminCredentials.new(credentials: credentials)

      error = assert_raises(AdminCredentials::Error) { writer.write(email: "admin@atesoraroseta.com", password: "a" * 11) }
      assert_equal "La contraseña debe tener al menos 12 caracteres.", error.message

      error = assert_raises(AdminCredentials::Error) { writer.write(email: "admin@atesoraroseta.com", password: "ñ" * 37) }
      assert_equal "La contraseña puede tener como máximo 72 bytes.", error.message

      error = assert_raises(AdminCredentials::Error) { writer.write(email: "admin", password: PASSWORD) }
      assert_equal "El correo electrónico no es válido.", error.message

      assert_equal before, File.binread(credentials.content_path)
    end
  end

  test "without the key it refuses, and never overwrites the file" do
    with_credentials do |credentials, dir|
      before = File.binread(credentials.content_path)
      keyless = encrypted(dir, File.join(dir, "missing.key"))

      error = assert_raises(AdminCredentials::Error) do
        AdminCredentials.new(credentials: keyless).write(email: "admin@atesoraroseta.com", password: PASSWORD)
      end
      assert_equal "Falta la clave maestra (config/master.key o RAILS_MASTER_KEY).", error.message
      assert_equal before, File.binread(credentials.content_path)
    end
  end

  test "with the wrong key it fails before writing" do
    with_credentials do |credentials, dir|
      before = File.binread(credentials.content_path)
      wrong_key = File.join(dir, "wrong.key")
      File.write(wrong_key, ActiveSupport::EncryptedFile.generate_key)

      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        AdminCredentials.new(credentials: encrypted(dir, wrong_key)).write(email: "admin@atesoraroseta.com", password: PASSWORD)
      end
      assert_equal before, File.binread(credentials.content_path)
    end
  end

  test "non-interactive with ADMIN_EMAIL and ADMIN_PASSWORD" do
    with_credentials do |credentials|
      output = run_task(credentials, env: { "ADMIN_EMAIL" => "admin@atesoraroseta.com", "ADMIN_PASSWORD" => PASSWORD })

      assert_equal "Guardado. Despliega para aplicarlo en producción.\n", output
      assert_equal PASSWORD, reread(credentials).dig(:admin, :password)
    end
  end

  test "asks for the email, with the default, and the password twice" do
    with_credentials do |credentials|
      output = run_task(credentials, input: "\n#{PASSWORD}\n#{PASSWORD}\n", interactive: true)

      assert_includes output, "Correo electrónico [admin@atesoraroseta.com]: "
      assert_includes output, "Contraseña (mínimo 12 caracteres): "
      assert_includes output, "Repite la contraseña: "
      assert output.end_with?("Guardado. Despliega para aplicarlo en producción.\n")
      assert_not_includes output, PASSWORD
      assert_equal "admin@atesoraroseta.com", reread(credentials).dig(:admin, :email)
      assert_equal PASSWORD, reread(credentials).dig(:admin, :password)
    end
  end

  test "the default email is the stored one" do
    content = TEMPLATE + "\nadmin:\n  email: artista@example.com\n  password: old-password-123\n"

    with_credentials(content) do |credentials|
      output = run_task(credentials, input: "\n#{PASSWORD}\n#{PASSWORD}\n", interactive: true)

      assert_includes output, "Correo electrónico [artista@example.com]: "
      assert_equal "artista@example.com", reread(credentials).dig(:admin, :email)
    end
  end

  test "asks again when the passwords differ or are too short, then gives up" do
    with_credentials do |credentials|
      input = "otro@example.com\ncorta\ncorta\n#{PASSWORD}\nno-coincide-1234\n#{PASSWORD}\n#{PASSWORD}\n"
      output = run_task(credentials, input: input, interactive: true)

      assert_includes output, "La contraseña debe tener al menos 12 caracteres."
      assert_includes output, "Las contraseñas no coinciden."
      assert_equal "otro@example.com", reread(credentials).dig(:admin, :email)

      error = assert_raises(AdminCredentials::Error) do
        run_task(credentials, input: "\n" + "a\nb\n" * 3, interactive: true)
      end
      assert_equal "Demasiados intentos; no se ha guardado nada.", error.message
    end
  end

  test "without a terminal or the variables it explains what to do" do
    with_credentials do |credentials|
      error = assert_raises(AdminCredentials::Error) { run_task(credentials, env: { "ADMIN_EMAIL" => "admin@atesoraroseta.com" }) }

      assert_equal "Define ADMIN_EMAIL y ADMIN_PASSWORD, o ejecuta la tarea en una terminal.", error.message
    end
  end

  test "replace_admin_block appends to a file without a trailing newline" do
    text = AdminCredentials.replace_admin_block("secret_key_base: abc", email: "a@example.com", password: PASSWORD)

    assert_equal "secret_key_base: abc\n\nadmin:\n  email: a@example.com\n  password: #{PASSWORD}\n", text
  end
end
