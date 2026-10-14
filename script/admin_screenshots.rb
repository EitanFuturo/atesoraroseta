# Screenshots of every admin screen, at 1280 and 800 px wide, into tmp/page-screenshots/admin/.
#
#   bin/rails server -p 3004                      # in another terminal, with the development seeds loaded
#   bin/rails runner script/admin_screenshots.rb
#
# Environment variables: PORT (3004), WIDTHS ("1280,800"), ONLY (names, e.g. "03-obras,07-torn-posters").
# It logs in as a throwaway user with a random password, never printed, and deletes that user at the end.
#
# Not tmp/screenshots, like bin/screenshots: that folder holds the system tests' failure screenshots, and
# Rails' tmp:clear (run by bin/setup, and so by bin/ci) fails on any folder inside it.
require "capybara"
require "selenium-webdriver"

module AdminScreenshots
  OUTPUT = Rails.root.join("tmp/page-screenshots/admin")
  WIDTHS = ENV.fetch("WIDTHS", "1280,800").split(",").map(&:to_i)
  ONLY = ENV["ONLY"]&.split(",")

  Capybara.register_driver :admin_screenshots do |app|
    options = Selenium::WebDriver::Chrome::Options.new
    options.add_argument("--headless=new")
    options.add_argument("--window-size=1280,900")
    options.add_argument("--hide-scrollbars")
    options.add_argument("--lang=es")
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end

  class << self
    def run
      FileUtils.mkdir_p(OUTPUT)
      Capybara.run_server = false
      Capybara.default_max_wait_time = 10
      Capybara.app_host = "http://127.0.0.1:#{ENV.fetch("PORT", "3004")}"
      @page = Capybara::Session.new(:admin_screenshots)
      user = User.create!(email_address: "capturas-#{SecureRandom.hex(4)}@example.com", password: SecureRandom.base58(24))

      begin
        capture_screens(user)
      ensure
        @page.driver.quit
        user.destroy!
        puts "Throwaway user deleted. Screenshots in #{OUTPUT.relative_path_from(Rails.root)}."
      end
    end

    private
      def capture_screens(user)
        @page.visit "/session/new"
        shot "01-login"

        log_in(user.email_address, "contraseña-equivocada")
        shot "02-login-error"

        log_in(user.email_address, user.password)
        @page.assert_selector "h1", text: "Obras"
        shot "03-obras"

        @page.visit "/admin/artworks/new"
        @page.assert_selector "lexxy-editor[connected]"
        shot "04-obra-nueva"

        @page.click_on "Crear la obra"
        @page.assert_selector ".error-summary"
        shot "05-obra-nueva-errores"

        @page.visit "/admin/artworks/#{Artwork.ordered.first.slug}/edit"
        @page.assert_selector "lexxy-editor[connected]"
        shot "06-obra-editar"

        @page.visit "/admin/torn-posters"
        shot "07-torn-posters"

        @page.visit "/admin/torn-posters/#{TornPoster.ordered.first.id}/edit"
        shot "08-torn-poster-editar"

        @page.visit "/admin/about/edit"
        @page.assert_selector "lexxy-editor[connected]"
        shot "09-sobre-mi"

        @page.visit "/admin/contact/edit"
        shot "10-contacto"

        @page.visit "/admin/site-texts/edit"
        shot "11-textos-del-sitio"
      end

      def log_in(email, password)
        @page.fill_in "Correo electrónico", with: email
        @page.fill_in "Contraseña", with: password
        @page.click_on "Entrar"
      end

      # The whole page at each width: the window grows to the page's height.
      def shot(name)
        return if ONLY && !ONLY.include?(name)

        WIDTHS.each do |width|
          resize(width, 900)
          height = @page.evaluate_script("Math.ceil(document.documentElement.scrollHeight)")
          resize(width, [ height, 900 ].max)
          path = OUTPUT.join("#{name}-#{width}.png")
          @page.save_screenshot(path.to_s)
          puts "Saved #{path.relative_path_from(Rails.root)}"
        end
        resize(1280, 900)
      end

      def resize(width, height)
        @page.driver.browser.manage.window.resize_to(width, height)
        sleep 0.4
        wait_for_images
      end

      def wait_for_images
        20.times do
          break if @page.evaluate_script("Array.from(document.images).every((image) => image.complete)")

          sleep 0.25
        end
      end
  end
end

AdminScreenshots.run
