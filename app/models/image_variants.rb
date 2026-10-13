# The named variants of the image attachments (overview §4.5), defined in one place.
#
# Sets an attachment can have (ImageAttachments#image_attachment's variants:), with their variant names:
#   :width     width_600, width_1200, width_2400       WebP, height follows the image   (artworks, details)
#   :square    square_600, square_1200, square_2400    WebP, centred square crops       (torn posters)
#   :portrait  portrait_600, portrait_1200, portrait_2400  WebP, centred 4:5 crops      (site portrait)
#   :og        og                                       1200×630 JPEG on the ground colour (artworks, site og_image)
#   :favicon   favicon_32, favicon_180, favicon_512     square PNGs                      (site favicon)
# Every attachment also gets thumb (WebP, up to 320 px on the long side) for the admin.
#
# All of them except thumb are preprocessed: Active Storage enqueues their TransformJobs right after
# upload, so no visitor waits. All are converted to sRGB and stripped of metadata (EXIF, XMP, ICC);
# WebP and PNG keep alpha. None is upscaled, except the favicons, which must be exact sizes.
#
# Transformation values are strings, integers, arrays and hashes only, never symbols: the variant URL
# carries them JSON-encoded, and a symbol would come back as a string with a different digest, so the
# preprocessed variant wouldn't be found and the first visitor would trigger a second transform.
module ImageVariants
  # The responsive families: variant name and box (width, height; nil height = follows the image).
  FAMILIES = {
    width: { width_600: [ 600, nil ], width_1200: [ 1200, nil ], width_2400: [ 2400, nil ] },
    square: { square_600: [ 600, 600 ], square_1200: [ 1200, 1200 ], square_2400: [ 2400, 2400 ] },
    portrait: { portrait_600: [ 600, 750 ], portrait_1200: [ 1200, 1500 ], portrait_2400: [ 2400, 3000 ] }
  }.freeze

  OG_SIZE = [ 1200, 630 ].freeze
  FAVICON_SIZES = [ 32, 180, 512 ].freeze
  THUMB_SIZE = 320

  # The page background, #222221, behind the og image's padding and any transparency.
  GROUND = [ 34, 34, 33 ].freeze
  WEBP_QUALITY = 82
  JPEG_QUALITY = 85

  SETS = (FAMILIES.keys + %i[og favicon]).freeze

  class << self
    # Declares the variants of +sets+, plus thumb, on a has_one_attached reflection.
    def define(attachable, sets)
      sets.each do |set|
        variants(set).each do |name, transformations|
          attachable.variant name, transformations.merge(preprocessed: true)
        end
      end

      attachable.variant :thumb, thumb
    end

    # { name => transformations } for one set.
    def variants(set)
      case set
      when :width
        FAMILIES[:width].to_h { |name, (width, _)| [ name, webp({ resize_to_limit: [ width, nil, srgb ] }) ] }
      when :square, :portrait
        FAMILIES[set].to_h { |name, (width, height)| [ name, webp({ resize_to_fill_limit: [ width, height, srgb ] }) ] }
      when :og
        { og: og }
      when :favicon
        FAVICON_SIZES.to_h { |size| [ :"favicon_#{size}", favicon(size) ] }
      else
        raise ArgumentError, "Unknown variant set #{set.inspect}; use one of #{SETS.inspect}"
      end
    end

    # The responsive family among +sets+ (:width, :square or :portrait), if any.
    def family_in(sets)
      (sets & FAMILIES.keys).first
    end

    private
      def webp(operations, quality: WEBP_QUALITY)
        operations.merge(format: "webp", saver: { quality: quality }.merge(no_metadata))
      end

      # Contained in 1200×630 (never upscaled), transparency flattened and padded on the ground colour.
      def og
        width, height = OG_SIZE
        {
          resize_and_flatten: [ width, height, { background: GROUND.dup }.merge(srgb) ],
          format: "jpg",
          saver: { quality: JPEG_QUALITY }.merge(no_metadata)
        }
      end

      # Exactly size × size: a centred square crop, scaled up if the upload is smaller.
      def favicon(size)
        { resize_to_fill: [ size, size, srgb ], format: "png", saver: no_metadata }
      end

      def thumb
        webp({ resize_to_limit: [ THUMB_SIZE, THUMB_SIZE, srgb ] }, quality: 80).merge(preprocessed: false)
      end

      # Converts colour-managed images (Display P3, Adobe RGB, CMYK…) to sRGB while resizing. Without it
      # libvips keeps the original colour space, and stripping its profile would shift the colours.
      def srgb
        { export_profile: "srgb" }
      end

      # Removes EXIF (including GPS), XMP, IPTC and ICC data: keep for libvips 8.15+, strip for older ones.
      def no_metadata
        { strip: true, keep: "none" }
      end
  end
end
