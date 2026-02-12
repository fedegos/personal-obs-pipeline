require "test_helper"

# En Docker usamos Chromium (CHROME_PATH). En CI/host, el :headless_chrome por defecto.
if (chrome_binary = ENV["CHROME_PATH"]) && File.exist?(chrome_binary)
  Capybara.register_driver :headless_chrome do |app|
    opts = Selenium::WebDriver::Chrome::Options.new
    opts.binary = chrome_binary
    opts.add_argument("--headless=new")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--disable-dev-shm-usage")
    opts.add_argument("--disable-gpu")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: opts)
  end
end

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
