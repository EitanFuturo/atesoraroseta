require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Keep the browser console, so tests can check that pages run without errors (CSP violations included).
    options.logging_prefs = { browser: "ALL" }
  end

  # The browser's console errors since the last read (reading empties the log): uncaught exceptions and
  # Content Security Policy violations. Failed requests are left out, since a form that comes back with
  # errors (422) is logged as one.
  def browser_errors
    page.driver.browser.logs.get(:browser)
      .select { |entry| entry.level == "SEVERE" && !entry.message.include?("Failed to load resource") }
      .map(&:message)
  end

  def assert_no_browser_errors
    errors = browser_errors
    assert_empty errors, "Browser console errors:\n#{errors.join("\n")}"
  end
end
