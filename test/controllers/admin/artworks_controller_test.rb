require "test_helper"

class Admin::ArtworksControllerTest < ActionDispatch::IntegrationTest
  include ActionView::RecordIdentifier

  setup { sign_in_as users(:one) }

  test "the list shows every work in the public order, with its status and warnings" do
    get admin_artworks_path

    assert_response :success
    assert_select "title", "Obras — Panel de atesoraroseta"
    assert_select "h1", "Obras"
    assert_select ".admin-nav a[aria-current=page]", "Obras"
    assert_equal [ "Collage de prueba", "Obra con periodo", "Obra sin publicar", "Obra sin datos" ],
      css_select("tbody .records__title").map(&:text)

    assert_select "##{dom_id(artworks(:collage))}" do
      assert_select ".badge--published", "Publicada"
      assert_select ".records__facts", "2024 · 2 detalles"
      assert_select ".warning", text: "Imagen pequeña" # obra-01.webp is 1179 × 1571
      assert_select ".warning", text: "1 detalle sin texto alternativo"
      assert_select "a[href=?][target=_blank]", artwork_path(artworks(:collage)), text: /Ver en la web/
    end

    assert_select "##{dom_id(artworks(:range))}" do
      assert_select ".records__facts", "2022–2023"
      assert_select ".warning", text: "Falta el texto alternativo"
    end

    assert_select "##{dom_id(artworks(:draft))}" do
      assert_select ".badge--draft", "Borrador"
      assert_select "a[href=?]", artwork_path(artworks(:draft)), text: /vista previa/
    end
  end

  test "the admin root is the list" do
    get admin_root_path

    assert_response :success
    assert_select "h1", "Obras"
  end

  test "an empty list says so" do
    Artwork.destroy_all

    get admin_artworks_path

    assert_select ".empty-state", "Todavía no hay obras."
  end
end
