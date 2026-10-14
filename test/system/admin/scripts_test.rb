require_relative "../admin_system_test_case"

class Admin::ScriptsTest < AdminSystemTestCase
  test "the panel's scripts start under the Content Security Policy" do
    visit admin_root_path

    assert_selector "h1", text: "Obras"
    assert_script "typeof window.Turbo === 'object'"
    assert_script "typeof window.Stimulus === 'object'"
    assert_script "customElements.get('lexxy-editor') !== undefined"
    assert_no_browser_errors
  end

  private
    # Waits for a JavaScript expression to be true (the import map loads modules asynchronously).
    def assert_script(expression)
      deadline = Time.current + Capybara.default_max_wait_time
      sleep 0.05 until page.evaluate_script(expression) || Time.current > deadline

      assert page.evaluate_script(expression), "Expected #{expression}"
    end
end
