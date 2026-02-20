require "test_helper"

# En Docker (CHROME_PATH): Cuprite + Chromium. En host: Selenium :headless_chrome.
if (chrome_binary = ENV["CHROME_PATH"]) && File.exist?(chrome_binary)
  require "capybara/cuprite"
  Capybara.register_driver :headless_chrome do |app|
    Capybara::Cuprite::Driver.new(
      app,
      browser_path: chrome_binary,
      headless: true,
      window_size: [ 1400, 1400 ],
      browser_options: {
        "no-sandbox": nil,
        "disable-dev-shm-usage": nil,
        "disable-gpu": nil,
        "disable-software-rasterizer": nil
      },
      timeout: 10,
    )
  end
  SYSTEM_DRIVER = :headless_chrome
  SYSTEM_DRIVER_OPTS = { screen_size: [ 1400, 1400 ] }
else
  SYSTEM_DRIVER = :selenium
  SYSTEM_DRIVER_OPTS = { using: :headless_chrome, screen_size: [ 1400, 1400 ] }
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include Warden::Test::Helpers
  driven_by SYSTEM_DRIVER, **SYSTEM_DRIVER_OPTS
  setup { Warden.test_mode! }
  teardown { Warden.test_reset! }

  # Helper para iniciar sesión en system tests
  def sign_in_as(user, _password: "password")
    login_as(user, scope: :user)
  end

  # Helper para cerrar sesión
  def sign_out
    click_link "Cerrar sesión" rescue click_button "Cerrar sesión"
  end
end
