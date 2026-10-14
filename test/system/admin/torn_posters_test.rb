require_relative "../admin_system_test_case"

class Admin::TornPostersTest < AdminSystemTestCase
  setup { @street, @wall, @draft = torn_posters(:street), torn_posters(:wall), torn_posters(:draft) }

  test "uploading several photos at once and publishing them" do
    visit admin_torn_posters_path

    attach_file "Fotos", [ file_fixture("small.png"), file_fixture("obra-01-d5.jpg") ], make_visible: true
    assert_selector ".uploads li .uploads__status", text: "Lista para subir", count: 2
    click_on "Subir las fotos"

    assert_text "Se han subido 2 fotos. Están sin publicar: revisa sus datos y publícalas."
    added = TornPoster.ordered.first(2)
    assert_equal [ "small.png", "obra-01-d5.jpg" ], added.map { |poster| poster.image.filename.to_s }
    assert added.none?(&:published?)
    assert_selector "tbody tr", count: 5

    fill_in "torn_posters_#{added.first.id}_place", with: "Calle de Atocha"
    click_on "Marcar todas como publicadas"

    assert_text "Cambios guardados. Todas las fotos están publicadas."
    assert TornPoster.all.all?(&:published?)
    assert_equal "Calle de Atocha", added.first.reload.place
    assert_no_browser_errors
  end

  test "reordering photos and saving the table" do
    visit admin_torn_posters_path

    click_on "Bajar la foto 1 un puesto"

    assert_text "La foto ha bajado un puesto."
    assert_equal [ @wall, @street, @draft ], TornPoster.ordered.to_a

    fill_in "torn_posters_#{@draft.id}_years", with: "2023-24"
    uncheck "torn_posters_#{@street.id}_published"
    click_on "Guardar cambios", match: :first

    assert_text "Cambios guardados."
    assert_field "torn_posters_#{@draft.id}_years", with: "2023–2024"
    assert_equal [ 2023, 2024 ], [ @draft.reload.year, @draft.year_end ]
    assert_not @street.reload.published?
  end

  test "deleting a photo with unsaved changes in the table asks twice" do
    visit admin_torn_posters_path
    fill_in "torn_posters_#{@street.id}_place", with: "Sin guardar"

    dismiss_confirm("Hay cambios sin guardar en esta página. Si continúas, se perderán. ¿Continuar?") do
      click_on "Eliminar la foto 2"
    end
    assert_equal 3, TornPoster.count

    accept_confirm("¿Eliminar la foto 2? No se puede deshacer.") do
      accept_confirm("Hay cambios sin guardar en esta página. Si continúas, se perderán. ¿Continuar?") do
        click_on "Eliminar la foto 2"
      end
    end

    assert_text "Foto eliminada."
    assert_equal [ @street, @draft ], TornPoster.ordered.to_a
  end
end
