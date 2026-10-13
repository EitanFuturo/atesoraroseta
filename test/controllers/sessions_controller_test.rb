require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  INVALID = "El correo electrónico o la contraseña no son correctos."
  RATE_LIMITED = "Demasiados intentos. Espera unos minutos y vuelve a intentarlo."

  setup { @user = users(:one) }

  test "the login page is in Spanish, with no password recovery and no sign-up" do
    get new_session_path

    assert_response :success
    assert_select "html[lang=es]"
    assert_select "title", "Entrar — Panel de atesoraroseta"
    assert_select "h1", "Entrar al panel"
    assert_select "label[for=email_address]", "Correo electrónico"
    assert_select "label[for=password]", "Contraseña"
    assert_select "input[type=submit][value=Entrar]"
    assert_select "a", text: /contraseña|olvid|regist|cuenta/i, count: 0
    assert_select "nav", count: 0
  end

  test "logging in goes to the admin" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to admin_root_url
    assert cookies[:session_id]
  end

  test "logging in returns to the admin page that asked for it" do
    get admin_artworks_url
    assert_redirected_to new_session_url

    post session_path, params: { email_address: @user.email_address, password: "password" }
    assert_redirected_to admin_artworks_url
  end

  test "a wrong password is refused in Spanish" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_equal INVALID, flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "a logged-in admin who opens the login page goes to the admin" do
    sign_in_as(@user)

    get new_session_path
    assert_redirected_to admin_root_url
  end

  test "logging out" do
    sign_in_as(@user)

    delete session_path

    assert_redirected_to new_session_path
    assert_equal "Has cerrado la sesión.", flash[:notice]
    assert_empty cookies[:session_id]
  end

  test "at most 5 login attempts per 10 minutes per IP" do
    with_login_attempts_counted do
      5.times do
        post session_path, params: { email_address: @user.email_address, password: "wrong" }
        assert_equal INVALID, flash[:alert]
      end

      # The sixth attempt is refused, even with the right password.
      post session_path, params: { email_address: @user.email_address, password: "password" }
      assert_redirected_to new_session_path
      assert_equal RATE_LIMITED, flash[:alert]
      assert_nil cookies[:session_id]

      travel 11.minutes do
        post session_path, params: { email_address: @user.email_address, password: "password" }
        assert_redirected_to admin_root_url
      end
    end
  end

  test "an old browser gets a Spanish page instead of the login form" do
    old_chrome = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/90.0.4430.212 Safari/537.36"

    get new_session_path, headers: { "User-Agent" => old_chrome }

    assert_response :not_acceptable
    assert_select "html[lang=es]"
    assert_select "h1", "Este navegador es demasiado antiguo para el panel"
  end

  private
    # The test environment's cache is a null store, which never counts, and the rate limiter captured
    # SessionsController's store when the class loaded. So for this test that same store object counts
    # in a fresh memory store.
    def with_login_attempts_counted
      store = SessionsController.cache_store
      memory_store = ActiveSupport::Cache::MemoryStore.new
      store.define_singleton_method(:increment) { |*args, **options| memory_store.increment(*args, **options) }

      yield
    ensure
      store.singleton_class.send(:remove_method, :increment)
    end
end
