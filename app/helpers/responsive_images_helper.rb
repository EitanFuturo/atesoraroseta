# Responsive <img> tags for the public pages (overview §4.5): a srcset of the variants that exist, at their
# real widths; sizes from the layout math; width and height from the original; and the loading policy.
#
#   image = ResponsiveImage.new(artwork.image)
#   responsive_image_tag image, sizes: obra_tile_sizes(image), alt: artwork.alt_text,
#     loading: :eager, fetchpriority: :high, class: "work-img"
#
# sizes: the content width is min(100vw, 1440px) − 2 × clamp(20px, 4.45vw, 64px), which is 1312px from 1440px
# up and at most 91.1vw below. Each layout below follows from its grid or flex formula, and errs slightly large:
# lengths are rounded up, and every column switch sits ~17px after the layout's own, so a classic scrollbar
# (it narrows the layout, not the media queries) never makes a value too small.
module ResponsiveImagesHelper
  # Layouts are lists of [min viewport (px), vw, px], widest first: "from this viewport width up, the image is
  # vw% of the viewport plus px wide". The last one starts at 0.

  # Obra tile: the column, times the frame's share of its 4:5 cell (ResponsiveImage#frame_width_percent).
  # auto-fill columns of at least 300px with a clamp(36px, 3.9vw, 56px) gap: 3 columns from ~1081px, 2 from
  # ~699px. Phones (site.css, up to 640px) show every work at the full content width.
  OBRA_TILE_LAYOUT = [ [ 1440, 0, 400 ], [ 1100, 27.77, 0 ], [ 720, 45.55, -18 ], [ 0, 91.1, 0 ] ].freeze
  OBRA_PHONE_SIZE = "(max-width: 640px) 91.1vw".freeze

  # Artwork hero: the media column beside the 300–360px text column from ~993px (content width − gap − 300px),
  # the full content width once wrapped. The image is also at most 860px tall and never wider than the original
  # (width: auto renders it at its sizes width), so the value is capped per image: artwork_hero_sizes.
  ARTWORK_HERO_LAYOUT = [ [ 1440, 0, 948 ], [ 1010, 86.65, -300 ], [ 0, 91.1, 0 ] ].freeze
  ARTWORK_HERO_MAX_HEIGHT = 860

  # Detail photos: columns: 3 300px, column-gap 24px: 3 columns from ~1041px, 2 from ~685px.
  DETAIL_LAYOUT = [ [ 1440, 0, 422 ], [ 1058, 30.37, -16 ], [ 702, 45.55, -12 ], [ 0, 91.1, 0 ] ].freeze

  # Torn Posters (site.css .photo-grid, media queries, so no scrollbar margin): 4 columns with a 20px gap from
  # 1024px, 3 with 20px from 641px, 2 with 12px below.
  POSTER_LAYOUT = [ [ 1440, 0, 313 ], [ 1024, 22.78, -15 ], [ 641, 30.37, -13.33 ], [ 0, 45.55, -6 ] ].freeze

  # Sobre mí portrait: beside the text from ~877px, sharing the free space with it (320px + half of it), at most
  # 540px; 540px or the full width once wrapped.
  PORTRAIT_LAYOUT = [ [ 894, 42.2, -50 ], [ 0, 91.1, 0 ] ].freeze
  PORTRAIT_MAX_WIDTH = 540

  # Eager images: the first row (overview §4.5).
  OBRA_EAGER_TILES = 3
  POSTER_EAGER_TILES = 4

  # An <img> with srcset, sizes, width and height. Lazy images also decode asynchronously; eager ones carry no
  # loading attribute (eager is the default).
  #
  # Without width/height metadata (an image that couldn't be analysed) there are no candidates: the image is
  # its family's middle variant, unsized.
  def responsive_image_tag(image, sizes:, alt:, loading: :lazy, fetchpriority: nil, **html_options)
    candidates = image.candidates
    attributes =
      if candidates.any?
        {
          src: url_for(image.variant(candidates[candidates.size / 2])),
          srcset: candidates.map { |candidate| "#{url_for(image.variant(candidate))} #{candidate.width}w" }.join(", "),
          sizes: sizes, width: image.width, height: image.height
        }
      else
        { src: url_for(image.variant(ImageVariants::FAMILIES.fetch(image.family).keys[1])) }
      end
    lazy = loading.to_s == "lazy"

    tag.img(**attributes, alt: alt, loading: ("lazy" if lazy), decoding: ("async" if lazy),
      fetchpriority: fetchpriority, **html_options)
  end

  def obra_tile_sizes(image)
    share = image.frame_width_percent ? image.frame_width_percent / 100.0 : 1
    "#{OBRA_PHONE_SIZE}, #{sizes_value(OBRA_TILE_LAYOUT, scale: share)}"
  end

  def artwork_hero_sizes(image)
    return sizes_value(ARTWORK_HERO_LAYOUT) unless image.dimensions?

    sizes_value(ARTWORK_HERO_LAYOUT, max: [ image.width, (ARTWORK_HERO_MAX_HEIGHT * image.aspect_ratio).ceil ].min)
  end

  def detail_sizes
    sizes_value(DETAIL_LAYOUT)
  end

  def poster_sizes
    sizes_value(POSTER_LAYOUT)
  end

  def portrait_sizes
    sizes_value(PORTRAIT_LAYOUT, max: PORTRAIT_MAX_WIDTH)
  end

  # :eager for the first +count+ images of a grid, :lazy for the rest.
  def grid_loading(index, eager:)
    index < eager ? :eager : :lazy
  end

  # A sizes value from a layout, scaled (an Obra tile's share of its cell) and capped at +max+ px.
  #
  #   sizes_value([ [ 894, 42.2, -50 ], [ 0, 91.1, 0 ] ], max: 540)
  #   # => "(min-width: 1399px) 540px, (min-width: 894px) calc(42.2vw - 50px), (min-width: 593px) 540px, 91.1vw"
  def sizes_value(layout, scale: 1, max: nil)
    segments = layout.map { |min_viewport, vw, px| [ min_viewport, vw * scale, px * scale ] }
    segments = cap_segments(segments, max) if max

    segments.map { |min_viewport, vw, px| [ min_viewport, css_length(vw, px) ] }
      .chunk_while { |wider, narrower| wider.last == narrower.last }.map(&:last)
      .map { |min_viewport, length| min_viewport.zero? ? length : "(min-width: #{min_viewport}px) #{length}" }
      .join(", ")
  end

  private
    # Replaces each segment's width by +max+ from the viewport where it reaches it (widths grow with the viewport).
    def cap_segments(segments, max)
      wider_start = nil

      segments.flat_map do |min_viewport, vw, px|
        capped =
          if vw.zero?
            [ [ min_viewport, 0, [ px, max ].min ] ]
          else
            reaches_max = ((max - px) * 100.0 / vw).round(6).ceil
            if reaches_max <= min_viewport
              [ [ min_viewport, 0, max ] ]
            elsif wider_start && reaches_max >= wider_start
              [ [ min_viewport, vw, px ] ]
            else
              [ [ reaches_max, 0, max ], [ min_viewport, vw, px ] ]
            end
          end
        wider_start = min_viewport
        capped
      end
    end

    # "400px", "91.1vw" or "calc(45.55vw - 18px)", rounded up (vw to 2 decimals, px to whole pixels).
    def css_length(vw, px)
      vw = (vw * 100).round(6).ceil / 100r
      px = px.round(6).ceil
      return "#{px}px" if vw.zero?
      return "#{css_number(vw)}vw" if px.zero?

      "calc(#{css_number(vw)}vw #{px.negative? ? "-" : "+"} #{px.abs}px)"
    end

    def css_number(number)
      number.denominator == 1 ? number.to_i.to_s : number.to_f.to_s
    end
end
