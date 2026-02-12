require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Helper para iniciar sesión en system tests
  def sign_in_as(user, password: "password")
    visit new_user_session_path
    fill_in "Email", with: user.email
    fill_in "Password", with: password
    click_button "Log in"
    assert_text "Signed in successfully" # Flash de Devise
  end

  # Helper para cerrar sesión
  def sign_out
    click_link "Cerrar sesión" rescue click_button "Cerrar sesión"
  end
end
