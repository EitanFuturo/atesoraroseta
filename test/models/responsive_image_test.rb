require "test_helper"

class ResponsiveImageTest < ActiveSupport::TestCase
  # An unsaved record whose attachment's blob has only metadata: enough for ResponsiveImage.
  def attachment_of(width, height, model: Artwork, name: :image)
    metadata = { identified: true, analyzed: true, width: width, height: height }.compact
    blob = ActiveStorage::Blob.new(filename: "obra.jpg", content_type: "image/jpeg", metadata: metadata)
    model.new(name => blob).public_send(name)
  end

  def responsive(width, height, **options)
    ResponsiveImage.new(attachment_of(width, height, **options))
  end

  def sizes(image)
    image.candidates.map { |candidate| [ candidate.name, candidate.width, candidate.height ] }
  end

  test "the canvas tiles' frame widths and aspect ratios" do
    {
      [ 1179, 1571 ] => [ 93.81, "93.81%" ],
      [ 620, 480 ] => [ 100.0, "100%" ],
      [ 300, 560 ] => [ 66.96, "66.96%" ],
      [ 560, 560 ] => [ 100.0, "100%" ],
      [ 460, 600 ] => [ 95.83, "95.83%" ],
      [ 680, 408 ] => [ 100.0, "100%" ],
      [ 380, 470 ] => [ 100.0, "100%" ],
      [ 600, 400 ] => [ 100.0, "100%" ],
      [ 535, 420 ] => [ 100.0, "100%" ]
    }.each do |(width, height), (percent, css)|
      image = responsive(width, height)

      assert_equal percent, image.frame_width_percent, "#{width}×#{height}"
      assert_equal css, image.frame_width_css, "#{width}×#{height}"
      assert_equal "#{width} / #{height}", image.aspect_ratio_css
    end
  end

  test "width and height are the original's" do
    image = ResponsiveImage.new(artworks(:collage).image)

    assert_equal [ 1179, 1571 ], [ image.width, image.height ]
    assert image.dimensions?
    assert_in_delta 0.7505, image.aspect_ratio, 0.0001
    assert image.low_resolution?
    assert_not responsive(2400, 1800).low_resolution?
  end

  test "width candidates stop at the original width, with its real height" do
    image = ResponsiveImage.new(artworks(:collage).image)

    assert_equal :width, image.family
    assert_equal [ [ :width_600, 600, 799 ], [ :width_1200, 1179, 1571 ] ], sizes(image)
  end

  test "width candidates for a large and a small original" do
    assert_equal [ [ :width_600, 600, 450 ], [ :width_1200, 1200, 900 ], [ :width_2400, 2400, 1800 ] ], sizes(responsive(4032, 3024))
    assert_equal [ [ :width_600, 600, 750 ], [ :width_1200, 1200, 1500 ], [ :width_2400, 2400, 3000 ] ], sizes(responsive(2400, 3000))
    assert_equal [ [ :width_600, 300, 560 ] ], sizes(responsive(300, 560)), "just the original width"
    assert_equal [ [ :width_600, 600, 400 ] ], sizes(responsive(600, 400))
    assert_equal [ [ :width_600, 600, 375 ], [ :width_1200, 1200, 750 ], [ :width_2400, 1600, 1000 ] ], sizes(responsive(1600, 1000))
  end

  test "detail images use the width family" do
    assert_equal [ [ :width_600, 340, 420 ] ], sizes(ResponsiveImage.new(artwork_details(:collage_first).image))
  end

  test "square candidates for torn posters" do
    assert_equal [ [ :square_600, 600, 600 ] ], sizes(ResponsiveImage.new(torn_posters(:street).image)) # 800×600
    assert_equal [ [ :square_600, 600, 600 ], [ :square_1200, 1200, 1200 ], [ :square_2400, 1500, 1500 ] ],
      sizes(responsive(2000, 1500, model: TornPoster)), "the largest centred square of a smaller photo"
    assert_equal [ [ :square_600, 600, 600 ], [ :square_1200, 1200, 1200 ], [ :square_2400, 2400, 2400 ] ],
      sizes(responsive(4000, 3000, model: TornPoster))
    assert_equal [ [ :square_600, 400, 400 ] ], sizes(responsive(400, 900, model: TornPoster))
  end

  test "4:5 candidates for the portrait" do
    assert_equal [ [ :portrait_600, 336, 420 ] ], sizes(ResponsiveImage.new(sites(:main).portrait)) # 340×420
    assert_equal [ [ :portrait_600, 600, 750 ], [ :portrait_1200, 1200, 1500 ], [ :portrait_2400, 1600, 2000 ] ],
      sizes(responsive(1600, 2400, model: Site, name: :portrait))
  end

  test "without metadata there are no candidates and no sizes" do
    [ responsive(nil, nil), ResponsiveImage.new(Artwork.new.image) ].each do |image|
      assert_not image.dimensions?
      assert_empty image.candidates
      assert_nil image.width
      assert_nil image.aspect_ratio
      assert_nil image.aspect_ratio_css
      assert_nil image.frame_width_percent
      assert_nil image.frame_width_css
      assert_not image.low_resolution?
    end
  end

  test "the family can be given, and must exist" do
    assert_equal :square, ResponsiveImage.new(artworks(:collage).image, :square).family
    assert_raises(ArgumentError) { ResponsiveImage.new(artworks(:collage).image, :banner) }
    assert_raises(ArgumentError) { ResponsiveImage.new(sites(:main).og_image) }
  end

  test "variant gives the named variant of a candidate" do
    image = ResponsiveImage.new(artworks(:collage).image)
    expected = artworks(:collage).image.variant(:width_1200).variation.digest

    assert_equal expected, image.variant(image.candidates.last).variation.digest
    assert_equal expected, image.variant(:width_1200).variation.digest
  end

  test "the candidates' sizes are the processed variants' sizes" do
    artwork = Artwork.create!(title: "Recortada", image: fixture_attachable("obra-01.webp"))
    poster = TornPoster.create!(image: fixture_attachable("small.png"))
    site = sites(:main)
    site.update!(portrait: fixture_attachable("obra-01.webp"))

    [ artwork.image, poster.image, site.portrait ].each do |attachment|
      image = ResponsiveImage.new(attachment)
      image.candidates.each do |candidate|
        processed = Vips::Image.new_from_buffer(image.variant(candidate).processed.download, "")
        assert_equal [ candidate.width, candidate.height ], [ processed.width, processed.height ], candidate.name
      end
    end
  end
end
