# sitemap.xml: the four menu pages and every published artwork, with lastmod.
#
# lastmod is when the page's content last changed, as far as the records tell: the settings for every page
# (its texts appear on all of them), plus the artworks for Obra (unpublished ones too, since publishing or
# hiding one changes the grid) and the posters for Torn Posters. It is left out when nothing is stored yet.
class SitemapsController < PublicController
  def show
    artworks = Artwork.published.ordered.select(:id, :slug, :updated_at)

    @entries = [
      [ root_url, latest(site.updated_at, Artwork.maximum(:updated_at)) ],
      [ torn_posters_url, latest(site.updated_at, TornPoster.maximum(:updated_at)) ],
      [ about_url, site.updated_at ],
      [ contact_url, site.updated_at ],
      *artworks.map { |artwork| [ artwork_url(artwork), artwork.updated_at ] }
    ]
  end

  private
    def latest(*times)
      times.compact.max
    end
end
