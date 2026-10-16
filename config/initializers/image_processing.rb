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
#
# Variants resize on load. Active Storage loads every variant's source with loader(page: 0), and
# image_processing only resizes on load when there are no loader options, so each variant decoded the
# whole upload first: an 80-megapixel photo is 240 MB of pixels, held in memory or in a temporary file,
# once per variant and at the same time in each job thread. Page 0 is libvips' default anyway, so
# ResizeOnLoad drops it. The resize operations, these two included, then open the file with
# Vips::Image.thumbnail, which decodes JPEG and WebP already shrunk, reads PNG in one pass, and
# auto-rotates after shrinking. That keeps a variant of a 50 MB upload within a few tens of MB.
require "image_processing/vips"

module ImageVariantOperations
  def resize_to_fill_limit(width, height, **options)
    out_width, out_height = ::ImageGeometry.fill_limit(*upright_size, width, height)

    # When the image can't fill the box, the out size is its largest centred crop of the box's ratio:
    # covering it needs no scaling, so this only crops (and applies the colour options).
    thumbnail(out_width, out_height, crop: :centre, size: :down, **options)
  end

  def resize_and_flatten(width, height, background:, **options)
    image = thumbnail(width, height, size: :down, **options)
    image = image.flatten(background: background) if image.has_alpha?
    image.gravity(:centre, width, height, extend: :background, background: background)
  end

  private
    # The image's size once upright. A path is only opened, which reads the header but no pixels; a loaded
    # image was auto-rotated when it was loaded.
    def upright_size
      return [ image.width, image.height ] unless image.is_a?(String)

      header = ::Vips::Image.new_from_file(image)
      sideways = header.get_typeof("orientation").nonzero? && header.get("orientation").between?(5, 8)
      sideways ? [ header.height, header.width ] : [ header.width, header.height ]
    end
end

module ResizeOnLoad
  def call(loader: {}, **options)
    loader = loader.except(:page) if loader[:page] == 0
    super(loader: loader, **options)
  end
end

ImageProcessing::Vips::Processor.include(ImageVariantOperations)
ImageProcessing::Vips::Processor.singleton_class.prepend(ResizeOnLoad)
