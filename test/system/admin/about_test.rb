require_relative "../admin_system_test_case"

class Admin::AboutTest < AdminSystemTestCase
  test "editing Sobre mí: the lead, the rich-text body and a portrait upload" do
    visit admin_root_path
    within(".admin-nav") { click_on "Sobre mí" }

    fill_in "Sobre mí: frase principal", with: "Recojo carteles arrancados y los vuelvo a componer."
    assert_rich_text_editor "site_about_body"
    fill_in_rich_text "site_about_body", with: "Un párrafo nuevo sobre el taller."
    attach_file "Retrato", file_fixture("obra-01.webp"), make_visible: true
    assert_selector ".uploads li .uploads__status", text: "Lista para subir"
    fill_in "Texto alternativo del retrato", with: "La artista en el taller"
    click_on "Guardar cambios"

    assert_text "Cambios guardados."
    assert_selector ".image-field .dimensions", text: "1179 × 1571 px"
    site = Site.first
    assert_equal "Recojo carteles arrancados y los vuelvo a componer.", site.about_lead
    assert_equal "<p>Un párrafo nuevo sobre el taller.</p>", site.about_body.body.to_html.strip
    assert_equal "obra-01.webp", site.portrait.filename.to_s
    assert_equal "La artista en el taller", site.portrait_alt
    assert_no_browser_errors
  end

  test "the editor's Spanish toolbar adds bold, italic and links, and saves no inline styles" do
    visit edit_admin_about_path
    assert_rich_text_editor "site_about_body"
    fill_in_rich_text "site_about_body", with: "Texto con formato"
    find("#site_about_body-content").send_keys([ modifier_key, "a" ])

    click_on "Negrita"
    click_on "Cursiva"
    click_on "Enlace"
    fill_in "site_about_body-link-url", with: "https://example.com/taller"
    click_on "Enlazar"
    assert_selector "#site_about_body-content a", text: "Texto con formato"
    click_on "Guardar cambios"

    assert_text "Cambios guardados."
    html = Site.first.about_body.body.to_html
    assert_match %r{<a href="https://example.com/taller"}, html
    assert_match(/<(strong|b)\b/, html)
    assert_match(/<(em|i)\b/, html)
    assert_no_match(/style=/, html)
    assert_no_browser_errors
  end
end
