require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    # Keep the browser console, so tests can check that pages run without errors (CSP violations included).
    options.logging_prefs = { browser: "ALL" }
  end

  # Messages that aren't page errors: a request that failed on purpose (a form that comes back with errors
  # is a 422), and Chrome declining to show the "leave this page?" warning of a page with unsaved changes.
  IGNORED_BROWSER_MESSAGES = [ "Failed to load resource", "Blocked attempt to show a 'beforeunload' confirmation panel" ].freeze

  # The previous test's last page may log while the browser resets; start each test with an empty log.
  setup { browser_errors }

  # The browser's console errors since the last read (reading empties the log): uncaught exceptions and
  # Content Security Policy violations.
  def browser_errors
    page.driver.browser.logs.get(:browser)
      .select { |entry| entry.level == "SEVERE" && IGNORED_BROWSER_MESSAGES.none? { |message| entry.message.include?(message) } }
      .map(&:message)
  end

  def assert_no_browser_errors
    errors = browser_errors
    assert_empty errors, "Browser console errors:\n#{errors.join("\n")}"
  end
end
