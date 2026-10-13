require "test_helper"

class ImageAttachmentsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  teardown { ImageAttachments.avif_supported = nil }

  # A stored blob that was never uploaded: enough to exercise validations without a file.
  def blob_without_file(content_type:, byte_size: 1.megabyte, filename: "imagen")
    ActiveStorage::Blob.create!(
      key: ActiveStorage::Blob.generate_unique_secure_token, filename: filename, content_type: content_type,
      byte_size: byte_size, checksum: "x", metadata: { identified: true }
    )
  end

  def new_artwork(image)
    Artwork.new(title: "Obra nueva", image: image)
  end

  def vips_image(variant)
    Vips::Image.new_from_buffer(variant.processed.download, "")
  end

  # Validation

  test "accepts JPEG, PNG and WebP uploads" do
    %w[obra-01-d5.jpg small.png obra-01.webp].each do |filename|
      assert new_artwork(fixture_attachable(filename)).valid?, filename
    end
  end

  test "rejects files that aren't images, in Spanish" do
    artwork = new_artwork(fixture_attachable("not-an-image.txt"))

    assert_not artwork.valid?
    assert_equal [ "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)" ], artwork.errors.full_messages
  end

  test "rejects formats libvips could read but the site doesn't take" do
    artwork = new_artwork(blob_without_file(content_type: "image/gif"))

    assert_not artwork.valid?
    assert_equal [ "Imagen tiene un formato no admitido (usa JPEG, PNG o WebP)" ], artwork.errors.full_messages
  end

  test "rejects images over 25 MB" do
    assert new_artwork(blob_without_file(content_type: "image/jpeg", byte_size: 25.megabytes)).valid?

    artwork = new_artwork(blob_without_file(content_type: "image/jpeg", byte_size: 25.megabytes + 1))
    assert_not artwork.valid?
    assert_equal [ "Imagen pesa más de 25 MB" ], artwork.errors.full_messages
  end

  test "accepts AVIF only when libvips can read it" do
    ImageAttachments.avif_supported = false
    artwork = new_artwork(blob_without_file(content_type: "image/avif"))
    assert_not artwork.valid?
    assert_not_includes ImageAttachments.content_types, "image/avif"
    assert_equal "image/jpeg,image/png,image/webp", ImageAttachments.accept

    ImageAttachments.avif_supported = true
    assert new_artwork(blob_without_file(content_type: "image/avif")).valid?
    assert_includes ImageAttachments.content_types, "image/avif"
    assert_equal "JPEG, PNG, WebP o AVIF", ImageAttachments.format_names

    artwork = new_artwork(blob_without_file(content_type: "image/gif"))
    artwork.valid?
    assert_equal [ "Imagen tiene un formato no admitido (usa JPEG, PNG, WebP o AVIF)" ], artwork.errors.full_messages
  end

  test "the AVIF gate follows libvips" do
    ImageAttachments.avif_supported = nil
    supported = ImageAttachments.avif_supported?

    assert_includes [ true, false ], supported
    assert_not supported, "no .avif loader in this libvips" unless Vips.get_suffixes.include?(".avif")
  end

  test "only new uploads are checked, so older images stay editable" do
    ImageAttachments.avif_supported = true
    artwork = new_artwork(blob_without_file(content_type: "image/avif"))
    artwork.save!

    ImageAttachments.avif_supported = false
    assert artwork.reload.valid?
  end

  test "every attachment on the site is checked" do
    site = sites(:main)
    site.favicon.attach(fixture_attachable("not-an-image.txt"))
    site.og_image = fixture_attachable("not-an-image.txt")

    assert_not site.valid?
    assert_includes site.errors.full_messages, "Icono del sitio tiene un formato no admitido (usa JPEG, PNG o WebP)"
    assert_includes site.errors.full_messages, "Imagen para redes sociales tiene un formato no admitido (usa JPEG, PNG o WebP)"
  end

  # Analysis

  test "width and height exist right after save, without waiting for the AnalyzeJob" do
    artwork = new_artwork(fixture_attachable("obra-01.webp"))

    assert_no_enqueued_jobs only: ActiveStorage::AnalyzeJob do
      artwork.save!
    end

    metadata = artwork.image.blob.metadata
    assert_equal 1179, metadata["width"]
    assert_equal 1571, metadata["height"]
    assert metadata["analyzed"]
    assert_equal 1571, Artwork.find(artwork.id).image_height
  end

  test "a replaced image is analysed right away too" do
    artwork = artworks(:bare)
    artwork.update!(image: fixture_attachable("obra-01-d5.jpg"))

    assert_equal [ 340, 420 ], [ artwork.image_width, artwork.image_height ]
  end

  test "images added to an existing record are analysed right away" do
    site = sites(:main)
    site.update!(og_image: fixture_attachable("small.png"), favicon: fixture_attachable("obra-01-d5.jpg"))

    assert_equal [ 800, 600 ], [ site.og_image_width, site.og_image_height ]
    assert_equal [ 340, 420 ], [ site.favicon_width, site.favicon_height ]
  end

  test "details and posters are analysed right away" do
    detail = artworks(:range).details.create!(image: fixture_attachable("small.png"))
    poster = TornPoster.create!(image: fixture_attachable("obra-01-d5.jpg"))

    assert_equal 800, detail.image_width
    assert_equal 420, poster.image_height
  end

  test "an analysis failure doesn't fail the save" do
    artwork = new_artwork(blob_without_file(content_type: "image/jpeg"))

    assert_nothing_raised { artwork.save! }
    assert_not artwork.image.blob.analyzed?, "left for the AnalyzeJob"
  end

  # Size helpers

  test "width, height and aspect ratio come from the blob's metadata" do
    artwork = artworks(:collage)

    assert_equal 1179, artwork.image_width
    assert_equal 1571, artwork.image_height
    assert_in_delta 0.7505, artwork.image_aspect_ratio, 0.0001
    assert_nil Artwork.new.image_width
    assert_nil Artwork.new.image_aspect_ratio
  end

  test "low resolution means a long side under 1600 px" do
    artwork = artworks(:collage)
    blob = artwork.image.blob

    { [ 1179, 1571 ] => true, [ 1599, 900 ] => true, [ 1600, 900 ] => false, [ 900, 2400 ] => false }.each do |(width, height), low|
      blob.metadata = blob.metadata.merge("width" => width, "height" => height)
      assert_equal low, artwork.image_low_resolution?, "#{width}×#{height}"
    end

    assert_not Artwork.new.image_low_resolution?, "unknown size: no warning"
    assert sites(:main).portrait_low_resolution?
  end

  # Variants

  test "public variants are queued for processing right after upload; thumb is not" do
    assert_enqueued_jobs 4, only: ActiveStorage::TransformJob do # width_600, width_1200, width_2400, og
      new_artwork(fixture_attachable("small.png")).save!
    end

    assert_enqueued_jobs 3, only: ActiveStorage::TransformJob do # square_600, square_1200, square_2400
      TornPoster.create!(image: fixture_attachable("small.png"))
    end
  end

  test "the queued jobs build the variants" do
    artwork = new_artwork(fixture_attachable("small.png"))
    perform_enqueued_jobs(only: ActiveStorage::TransformJob) { artwork.save! }

    assert_equal 4, artwork.image.blob.variant_records.count

    # A view's variant URL carries the variation key; decoding it must find the preprocessed record.
    key = artwork.image.variant(:width_600).variation.key
    digest = ActiveStorage::Variation.wrap(key).default_to(format: "png").digest
    assert artwork.image.blob.variant_records.exists?(variation_digest: digest)
  end

  test "width variants are WebP, keep alpha, strip metadata and are never upscaled" do
    artwork = Artwork.create!(title: "Recortada", image: fixture_attachable("obra-01.webp"))

    small = vips_image(artwork.image.variant(:width_600))
    assert_equal [ 600, 799 ], [ small.width, small.height ]
    assert_equal 4, small.bands, "alpha kept"
    assert_operator small.extract_band(3).min, :<, 255, "the cut-out stays transparent"
    assert_equal "webpload_buffer", small.get("vips-loader")
    assert_empty small.get_fields.grep(/exif|xmp|icc|iptc/)

    large = vips_image(artwork.image.variant(:width_1200))
    assert_equal [ 1179, 1571 ], [ large.width, large.height ], "not upscaled"
  end

  test "detail images get the width variants" do
    image = vips_image(artwork_details(:collage_first).image.variant(:width_600))

    assert_equal [ 340, 420 ], [ image.width, image.height ]
  end

  test "poster variants are centred squares, never upscaled" do
    poster = TornPoster.create!(image: fixture_attachable("small.png")) # 800×600

    assert_equal [ 600, 600 ], vips_image(poster.image.variant(:square_600)).then { [ it.width, it.height ] }
    assert_equal [ 600, 600 ], vips_image(poster.image.variant(:square_1200)).then { [ it.width, it.height ] }

    # The left half of small.png is ochre and the right half blue-grey: a centred crop keeps both.
    square = vips_image(poster.image.variant(:square_600))
    assert_operator square.getpoint(10, 300)[0], :>, 150, "ochre on the left"
    assert_operator square.getpoint(590, 300)[0], :<, 120, "blue-grey on the right"
  end

  test "the portrait variants are centred 4:5 crops" do
    site = sites(:main)
    site.update!(portrait: fixture_attachable("obra-01.webp")) # 1179×1571

    image = vips_image(site.portrait.variant(:portrait_600))
    assert_equal [ 600, 750 ], [ image.width, image.height ]

    image = vips_image(site.portrait.variant(:portrait_1200))
    assert_equal [ 1179, 1474 ], [ image.width, image.height ], "the largest 4:5 crop, not upscaled"
    assert_equal 4, image.bands
  end

  test "og is a 1200×630 JPEG, contained and flattened on the ground colour" do
    artwork = Artwork.create!(title: "Recortada", image: fixture_attachable("obra-01.webp"))
    image = vips_image(artwork.image.variant(:og))

    assert_equal [ 1200, 630, 3 ], [ image.width, image.height, image.bands ]
    assert_equal "jpegload_buffer", image.get("vips-loader")
    assert_empty image.get_fields.grep(/exif|xmp|icc|iptc/)
    # The work is 473×630 in the middle (x 363 to 836): padding on both sides, and its transparent
    # left edge (x 0 to 10 in the original) flattened onto the ground colour, not black.
    { [ 5, 5 ] => "padding", [ 1194, 624 ] => "padding", [ 100, 315 ] => "padding", [ 1100, 315 ] => "padding",
      [ 366, 315 ] => "transparency" }.each do |(x, y), what|
      image.getpoint(x, y).zip([ 34, 34, 33 ]).each { |actual, ground| assert_in_delta ground, actual, 3, "#{what} at #{x},#{y}" }
    end
    assert_operator image.crop(400, 100, 400, 430).avg, :>, 80, "the work itself fills the middle"
  end

  test "og works for images without alpha, and for the site's social image" do
    site = sites(:main)
    site.update!(og_image: fixture_attachable("small.png"))
    image = vips_image(site.og_image.variant(:og))

    assert_equal [ 1200, 630, 3 ], [ image.width, image.height, image.bands ]
    image.getpoint(30, 300).zip([ 34, 34, 33 ]).each { |actual, ground| assert_in_delta ground, actual, 3 }
    assert_operator image.getpoint(500, 300)[0], :>, 150, "the image itself in the middle"
  end

  test "favicons are exact squares in PNG" do
    site = sites(:main)
    site.update!(favicon: fixture_attachable("obra-01-d5.jpg")) # 340×420

    { favicon_32: 32, favicon_180: 180, favicon_512: 512 }.each do |name, size|
      image = vips_image(site.favicon.variant(name))
      assert_equal [ size, size ], [ image.width, image.height ], name
      assert_equal "pngload_buffer", image.get("vips-loader")
    end
  end

  test "thumb fits in 320 px for the admin" do
    image = vips_image(artworks(:collage).image.variant(:thumb))

    assert_equal [ 240, 320 ], [ image.width, image.height ]
  end
end
