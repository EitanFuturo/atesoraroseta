# The <head> of the public pages (overview §4.3 and §4.9): the title, the meta description, the canonical
# URL, the Open Graph image and the favicons.
#
# Each view names its page once, and the layout writes the tags:
#
#   <% page_meta title: site.nav_about_label, description: site.about_lead, canonical: about_url %>
#   <% page_meta title: @artwork.title, description: @artwork.meta_description, canonical: artwork_url(@artwork),
#                og_image: @artwork.image.variant(:og), og_image_alt: @artwork.alt_text %>
#
# - The title reads "<page> — <wordmark>" ("Obra — atesoraroseta"), or just the wordmark.
# - A blank description falls back to the site's SEO description, and is left out when both are blank.
# - The social image is the page's own, else the site's (Site#og_image), else the first published artwork's;
#   all are the 1200×630 JPEG `og` variant, with absolute URLs.
module PageMetaHelper
  def page_meta(title: nil, description: nil, canonical: nil, og_image: nil, og_image_alt: nil)
    @page_meta = { title: title, description: description, canonical: canonical, og_image: og_image,
                   og_image_alt: og_image_alt }
    nil
  end

  def page_title
    [ page_meta_value(:title), site.wordmark ].compact_blank.join(" — ")
  end

  def page_description
    (page_meta_value(:description).presence || site.seo_description).to_s.squish.presence
  end

  def page_canonical_url
    page_meta_value(:canonical)
  end

  # The absolute URL of the page's social image, or nil when there is none (an empty site).
  def page_og_image_url
    variant, _alt = page_og_image
    rails_storage_proxy_url(variant) if variant
  end

  # The social image's alt text, when it is an artwork's.
  def page_og_image_alt
    page_og_image&.last.presence
  end

  # [ size, variant ] of each favicon <link>, or [] when the site has no icon (no default icon is linked).
  def favicon_variants
    return [] unless site.favicon.attached?

    ImageVariants::FAVICON_SIZES.map { |size| [ size, site.favicon.variant(:"favicon_#{size}") ] }
  end

  private
    def page_meta_value(key)
      @page_meta&.dig(key)
    end

    # [ variant, alt ] of the social image, or nil.
    def page_og_image
      return @page_og_image if defined?(@page_og_image)

      @page_og_image =
        if (variant = page_meta_value(:og_image))
          [ variant, page_meta_value(:og_image_alt) ]
        elsif site.og_image.attached?
          [ site.og_image.variant(:og), nil ]
        elsif (artwork = Artwork.published.ordered.with_attached_image.first)
          [ artwork.image.variant(:og), artwork.alt_text ]
        end
    end
end
