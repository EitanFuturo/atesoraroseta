require "application_system_test_case"

# Signed out, through the real form (the fixture user's throwaway password is "password").
class Admin::LoginTest < ApplicationSystemTestCase
  test "logging in: a wrong password fails, the right one works, and nothing offers recovery or sign-up" do
    visit admin_root_path

    assert_current_path new_session_path
    assert_selector "h1", text: "Entrar al panel"
    assert_no_selector "a", text: /contraseña|olvid|regist|cuenta/i
    assert_no_selector "nav"

    fill_in "Correo electrónico", with: users(:one).email_address
    fill_in "Contraseña", with: "no-es-la-contraseña"
    click_on "Entrar"

    assert_text "El correo electrónico o la contraseña no son correctos."
    assert_current_path new_session_path

    fill_in "Correo electrónico", with: users(:one).email_address
    fill_in "Contraseña", with: "password"
    click_on "Entrar"

    assert_selector "h1", text: "Obras"
    assert_current_path admin_root_path
    assert_no_browser_errors

    click_on "Cerrar sesión"

    assert_text "Has cerrado la sesión."
    visit admin_artworks_path
    assert_current_path new_session_path
  end
end
