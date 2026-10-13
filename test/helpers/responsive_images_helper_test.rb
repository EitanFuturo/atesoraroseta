require "test_helper"

# The sizes arithmetic of ResponsiveImagesHelper: layouts become media conditions, scaled for Obra tiles and
# capped for the artwork hero and the portrait, always rounded up.
class ResponsiveImagesHelperTest < ActionView::TestCase
  test "a layout becomes media conditions, widest first, with lengths rounded up" do
    assert_equal "(min-width: 1440px) 422px, (min-width: 1058px) calc(30.37vw - 16px), " \
      "(min-width: 702px) calc(45.55vw - 12px), 91.1vw", detail_sizes
    assert_equal "(min-width: 1440px) 313px, (min-width: 1024px) calc(22.78vw - 15px), " \
      "(min-width: 641px) calc(30.37vw - 13px), calc(45.55vw - 6px)", poster_sizes
    assert_equal "(min-width: 1399px) 540px, (min-width: 894px) calc(42.2vw - 50px), (min-width: 593px) 540px, 91.1vw",
      portrait_sizes
  end

  test "a cap replaces each segment's width from the viewport where it reaches the cap, and merges equal neighbours" do
    layout = [ [ 1440, 0, 948 ], [ 1010, 86.65, -300 ], [ 0, 91.1, 0 ] ]

    assert_equal "(min-width: 1440px) 948px, (min-width: 1010px) calc(86.65vw - 300px), 91.1vw", sizes_value(layout)
    assert_equal "(min-width: 1092px) 646px, (min-width: 1010px) calc(86.65vw - 300px), (min-width: 710px) 646px, 91.1vw",
      sizes_value(layout, max: 646)
    assert_equal "(min-width: 330px) 300px, 91.1vw", sizes_value(layout, max: 300)
  end

  test "an Obra tile's sizes scale with its frame's share of the cell; phones always get the full width" do
    square = ResponsiveImage.new(artworks(:range).image) # 800×600 fills its cell
    tall = ResponsiveImage.new(artworks(:collage).image) # 1179×1571: 93.81%

    assert_equal "(max-width: 640px) 91.1vw, (min-width: 1440px) 400px, (min-width: 1100px) 27.77vw, " \
      "(min-width: 720px) calc(45.55vw - 18px), 91.1vw", obra_tile_sizes(square)
    assert_equal "(max-width: 640px) 91.1vw, (min-width: 1440px) 376px, (min-width: 1100px) 26.06vw, " \
      "(min-width: 720px) calc(42.74vw - 16px), 85.47vw", obra_tile_sizes(tall)
  end

  test "the hero is never wider than 860px tall allows, nor than the original" do
    collage = ResponsiveImage.new(artworks(:collage).image) # 860 × 1179 / 1571 = 645.4
    detail = ResponsiveImage.new(artworks(:draft).image)    # 340×420: the original's 340 is less than 697

    assert_equal "(min-width: 1092px) 646px, (min-width: 1010px) calc(86.65vw - 300px), (min-width: 710px) 646px, 91.1vw",
      artwork_hero_sizes(collage)
    assert_equal "(min-width: 374px) 340px, 91.1vw", artwork_hero_sizes(detail)
  end

  test "an image tag: middle candidate as src, srcset with real widths, the original's size, lazy by default" do
    image = ResponsiveImage.new(artworks(:collage).image)
    html = responsive_image_tag(image, sizes: "100vw", alt: "Collage", class: "work-img")
    img = Nokogiri::HTML5.fragment(html).at("img")

    assert_equal url_for(image.variant(:width_1200)), img["src"]
    assert_equal "#{url_for(image.variant(:width_600))} 600w, #{url_for(image.variant(:width_1200))} 1179w", img["srcset"]
    assert_equal %w[100vw 1179 1571 Collage lazy async work-img],
      %w[sizes width height alt loading decoding class].map { |name| img[name] }
    assert_nil img["fetchpriority"]

    eager = Nokogiri::HTML5.fragment(responsive_image_tag(image, sizes: "100vw", alt: "", loading: :eager, fetchpriority: :high)).at("img")
    assert_nil eager["loading"]
    assert_nil eager["decoding"]
    assert_equal "high", eager["fetchpriority"]
    assert_equal "", eager["alt"]
  end

  test "an image without size metadata gets its family's middle variant, unsized" do
    blob = artworks(:bare).image.blob
    blob.update!(metadata: blob.metadata.except("width", "height"))
    image = ResponsiveImage.new(artworks(:bare).reload.image)

    img = Nokogiri::HTML5.fragment(responsive_image_tag(image, sizes: "100vw", alt: "Obra")).at("img")
    assert_equal url_for(image.variant(:width_1200)), img["src"]
    assert_nil img["srcset"]
    assert_nil img["width"]
  end
end
