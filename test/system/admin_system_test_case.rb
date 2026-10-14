require "application_system_test_case"

# Admin system tests: signed in as a fixture user (throwaway password), with helpers for the panel's
# JavaScript widgets.
class AdminSystemTestCase < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  # Types into a Lexxy rich-text editor. The editor is <lexxy-editor id="…"> and the editable area inside
  # it is a contenteditable <div id="<editor id>-content" role="textbox">, labelled by the field's <label>.
  def fill_in_rich_text(editor_id, with:)
    editable = find("##{editor_id}-content")
    editable.click
    editable.send_keys([ modifier_key, "a" ], :backspace)
    editable.send_keys(with)
  end

  # Waits until the editor has started (Lexxy defines its elements after a timeout).
  def assert_rich_text_editor(editor_id)
    assert_selector "##{editor_id}-content[contenteditable=true]"
  end

  # A copy of a fixture file under another name (for example a text file named .jpg), deleted after the test.
  def renamed_fixture_file(fixture, name)
    directory = Rails.root.join("tmp/system-test-files/#{SecureRandom.hex(4)}")
    FileUtils.mkdir_p(directory)
    FileUtils.cp(file_fixture(fixture), directory.join(name))
    @renamed_fixture_directories = [ *@renamed_fixture_directories, directory ]
    directory.join(name).to_s
  end

  teardown { Array(@renamed_fixture_directories).each { |directory| FileUtils.rm_rf(directory) } }

  private
    def modifier_key
      RUBY_PLATFORM.include?("darwin") ? :command : :control
    end
end
