require "test_helper"

class ImageVariantsTest < ActiveSupport::TestCase
  MODELS = [ Artwork, ArtworkDetail, TornPoster, Site ].freeze

  def each_named_variant
    MODELS.each do |model|
      model.attachment_reflections.each do |attachment, reflection|
        reflection.named_variants.each do |name, named_variant|
          yield model, attachment, name, named_variant
        end
      end
    end
  end

  test "each attachment has its variants, and thumb" do
    names = ->(model, attachment) { model.reflect_on_attachment(attachment).named_variants.keys }

    assert_equal %i[width_600 width_1200 width_2400 og thumb], names.(Artwork, :image)
    assert_equal %i[width_600 width_1200 width_2400 thumb], names.(ArtworkDetail, :image)
    assert_equal %i[square_600 square_1200 square_2400 thumb], names.(TornPoster, :image)
    assert_equal %i[portrait_600 portrait_1200 portrait_2400 thumb], names.(Site, :portrait)
    assert_equal %i[og thumb], names.(Site, :og_image)
    assert_equal %i[favicon_32 favicon_180 favicon_512 thumb], names.(Site, :favicon)
  end

  test "the responsive family of each attachment" do
    assert_equal({ image: :width }, Artwork.image_attachment_families)
    assert_equal({ image: :width }, ArtworkDetail.image_attachment_families)
    assert_equal({ image: :square }, TornPoster.image_attachment_families)
    assert_equal({ portrait: :portrait, og_image: nil, favicon: nil }, Site.image_attachment_families)
  end

  test "public variants are preprocessed, the admin thumb is not" do
    each_named_variant do |model, attachment, name, named_variant|
      assert_equal name != :thumb, named_variant.preprocessed, "#{model}##{attachment} #{name}"
    end
  end

  test "a variant's URL key decodes to the digest it was preprocessed under" do
    blob = ActiveStorage::Blob.new(filename: "obra.jpg", content_type: "image/jpeg")

    each_named_variant do |model, attachment, name, named_variant|
      variant = blob.variant(named_variant.transformations)
      from_url = blob.variant(variant.variation.key)

      assert_equal variant.variation.digest, from_url.variation.digest, "#{model}##{attachment} #{name}"
    end
  end

  test "variants convert to sRGB and strip metadata" do
    each_named_variant do |model, attachment, name, named_variant|
      transformations = named_variant.transformations
      resize = transformations.values_at(:resize_to_limit, :resize_to_fill_limit, :resize_to_fill, :resize_and_flatten).compact.first

      assert_equal "srgb", resize.last[:export_profile], "#{model}##{attachment} #{name}"
      assert_equal true, transformations.dig(:saver, :strip)
      assert_equal "none", transformations.dig(:saver, :keep)
    end
  end

  test "unknown sets are refused" do
    assert_raises(ArgumentError) { ImageVariants.variants(:banner) }
    assert_raises(ArgumentError) { Class.new(ApplicationRecord) { include ImageAttachments }.image_attachment(:x, variants: %i[banner]) }
  end
end
