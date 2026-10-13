# What a view needs to render an image attachment responsively: the original's size, the srcset
# candidates of its variant family and, for Obra tiles, the frame's width and aspect ratio.
# It builds no URLs or HTML; views turn candidates into a srcset with Rails' URL helpers.
#
#   image = ResponsiveImage.new(artwork.image)        # the family comes from the attachment (:width here)
#   image.width                                       # => 1179 (the original's metadata)
#   image.height                                      # => 1571
#   image.candidates                                  # => [#<data name=:width_600, width=600, height=799>,
#                                                     #     #<data name=:width_1200, width=1179, height=1571>]
#   image.variant(image.candidates.last)              # => artwork.image.variant(:width_1200)
#   image.frame_width_percent                         # => 93.81
#   image.frame_width_css                             # => "93.81%"
#   image.aspect_ratio_css                            # => "1179 / 1571"
#
#   srcset = image.candidates.map { |candidate| "#{url_for(image.variant(candidate))} #{candidate.width}w" }
#
# Families: :width (artworks and details), :square (torn posters), :portrait (the site portrait).
# Candidates are the family's variants at the size they actually come out at: never upscaled, so an image
# narrower than a variant's box yields its own width (or largest crop) once, deduplicated, smallest first.
# Without width and height metadata (not analysed, or unreadable) there are no candidates and the size
# methods return nil.
class ResponsiveImage
  Candidate = Data.define(:name, :width, :height)

  # Obra cells are 4:5, so a work at its own proportions is at most 125% × width / height of the cell's width.
  FRAME_FACTOR = 125

  attr_reader :attachment, :family

  def initialize(attachment, family = nil)
    @attachment = attachment
    @family = (family || family_of(attachment))&.to_sym

    unless ImageVariants::FAMILIES.key?(@family)
      raise ArgumentError, "No responsive variant family for #{attachment.name.inspect}; pass one of " \
        "#{ImageVariants::FAMILIES.keys.inspect}"
    end
  end

  def width
    metadata["width"]
  end

  def height
    metadata["height"]
  end

  # True when the original's width and height are known.
  def dimensions?
    width.to_i.positive? && height.to_i.positive?
  end

  # Width / height as a Float.
  def aspect_ratio
    width.fdiv(height) if dimensions?
  end

  # For CSS aspect-ratio: "1179 / 1571".
  def aspect_ratio_css
    "#{width} / #{height}" if dimensions?
  end

  # The Obra tile frame's width in percent of its cell: min(100, 125 × width / height), to 2 decimals.
  def frame_width_percent
    [ (FRAME_FACTOR * width).fdiv(height), 100.0 ].min.round(2) if dimensions?
  end

  # For the frame's style: "93.81%", or "100%" as the canvas writes it.
  def frame_width_css
    percent = frame_width_percent
    return if percent.nil?

    percent == 100 ? "100%" : format("%.2f%%", percent)
  end

  # True when the long side is under 1600 px (a warning for the admin).
  def low_resolution?
    dimensions? && [ width, height ].max < ImageAttachments::LOW_RESOLUTION_LONG_SIDE
  end

  # The family's variants that exist at distinct sizes, smallest first, each with its real pixel size.
  def candidates
    return [] unless dimensions?

    ImageVariants::FAMILIES.fetch(family).map do |name, (box_width, box_height)|
      size = box_height ? ImageGeometry.fill_limit(width, height, box_width, box_height) : ImageGeometry.limit_width(width, height, box_width)
      Candidate.new(name: name, width: size.first, height: size.last)
    end.uniq(&:width)
  end

  # The variant of a candidate (or of a variant name), ready for url_for / rails_storage_proxy_path.
  def variant(candidate)
    attachment.variant(candidate.is_a?(Candidate) ? candidate.name : candidate.to_sym)
  end

  private
    def metadata
      attachment.attached? ? attachment.blob.metadata : {}
    end

    def family_of(attachment)
      attachment.record.class.try(:image_attachment_families)&.dig(attachment.name.to_sym)
    end
end
