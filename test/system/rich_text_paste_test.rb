require_relative "admin_system_test_case"

# Text pasted into the editor arrives with its source's inline styles (alignment, colours). On public pages
# the only inline styles are the Obra tiles' sizes (overview §4.6), so none of them may reach rich text there.
# Two layers keep them out: Lexxy's own sanitiser, with highlights off in the admin, saves no text-align and no
# colour; and RichTextHelper#public_rich_text strips any style that is stored anyway.
class RichTextPasteTest < AdminSystemTestCase
  PASTED_HTML = '<p style="text-align: center">Un párrafo <span style="color: rgb(200, 0, 0)">centrado y en rojo</span>.</p>' \
    '<p style="text-align: right"><span style="background-color: rgb(255, 255, 0); color: rgb(0, 0, 200)">' \
    "Otro alineado a la derecha.</span></p>"

  test "a pasted paragraph's inline styles never reach the Sobre mí page" do
    visit edit_admin_about_path
    assert_rich_text_editor "site_about_body"
    paste_html "site_about_body", PASTED_HTML
    assert_selector "#site_about_body-content p", text: "Otro alineado a la derecha."
    click_on "Guardar cambios"
    assert_text "Cambios guardados."
    assert_includes Site.first.about_body.body.to_html, "Un párrafo centrado y en rojo."

    visit about_path
    assert_selector ".about-body p", text: "Un párrafo centrado y en rojo."
    assert_selector ".about-body p", text: "Otro alineado a la derecha."
    assert_no_selector ".about-body [style]"
    assert_no_selector "main [style]"
  end

  test "a pasted paragraph's inline styles never reach an artwork page" do
    artwork = artworks(:collage)
    visit edit_admin_artwork_path(artwork)
    assert_rich_text_editor "artwork_description"
    paste_html "artwork_description", PASTED_HTML
    assert_selector "#artwork_description-content p", text: "Otro alineado a la derecha."
    click_on "Guardar cambios", match: :first
    assert_text "Cambios guardados."
    assert_includes artwork.reload.description.body.to_html, "Un párrafo centrado y en rojo."

    visit artwork_path(artwork)
    assert_selector ".artwork-description p", text: "Un párrafo centrado y en rojo."
    assert_no_selector ".artwork-description [style]"
  end

  private
    # Replaces the editor's content with a paste of the given HTML, as the browser would deliver it.
    def paste_html(editor_id, html)
      editable = find("##{editor_id}-content")
      editable.click
      editable.send_keys([ modifier_key, "a" ], :backspace)
      page.execute_script(<<~JS, editable, html)
        const [target, html] = arguments
        const data = new DataTransfer()
        data.setData("text/html", html)
        const template = document.createElement("template")
        template.innerHTML = html
        data.setData("text/plain", template.content.textContent)
        target.dispatchEvent(new ClipboardEvent("paste", { clipboardData: data, bubbles: true, cancelable: true }))
      JS
    end
end
