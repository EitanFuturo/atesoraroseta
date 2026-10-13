# Two operations added to image_processing's libvips processor, so Active Storage variants can name
# them like the built-in ones (see ImageVariants):
#
#   resize_to_fill_limit: [ 600, 750, { export_profile: "srgb" } ]
#     Crops the centre of the image to the box's aspect ratio (the same crop as CSS object-fit: cover)
#     and scales it down to the box, but never up, which resize_to_fill can't do: given a box larger than
#     the image, it returns the largest centred crop of the box's ratio at the original resolution.
#     The square Torn Posters and the 4:5 portrait crops use it. ImageGeometry.fill_limit gives the size.
#
#   resize_and_flatten: [ 1200, 630, { background: [ 34, 34, 33 ], export_profile: "srgb" } ]
#     Contains the image in the box (never upscaled), flattens any transparency onto the background and
#     pads it to exactly the box with the same colour: the og image. libvips' own flatten treats the last
#     band as alpha whether or not there is one, so it can't be listed as a plain variant operation.
require "image_processing/vips"

module ImageVariantOperations
  def resize_to_fill_limit(width, height, **options)
    image = loaded_image
    out_width, out_height = ::ImageGeometry.fill_limit(image.width, image.height, width, height)
    options = { no_rotate: true, size: :down }.merge(options)

    if out_width == width && out_height == height
      image.thumbnail_image(width, height: height, crop: :centre, **options)
    else
      left = (image.width - out_width) / 2
      top = (image.height - out_height) / 2
      # Thumbnailing at the crop's own size scales nothing; it applies the colour options (export_profile).
      image.extract_area(left, top, out_width, out_height).thumbnail_image(out_width, height: out_height, **options)
    end
  end

  def resize_and_flatten(width, height, background:, **options)
    image = loaded_image.thumbnail_image(width, height: height, no_rotate: true, size: :down, **options)
    image = image.flatten(background: background) if image.has_alpha?
    image.gravity(:centre, width, height, extend: :background, background: background)
  end

  private
    # Active Storage always passes a loader, so the image is loaded (and auto-rotated) already; without
    # one, image_processing hands over the file path for resize operations.
    def loaded_image
      image.is_a?(String) ? self.class.load_image(image) : image
    end
end

ImageProcessing::Vips::Processor.include(ImageVariantOperations)
