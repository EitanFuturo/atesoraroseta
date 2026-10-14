# Obra (the home page's grid) and the artwork pages.
class ArtworksController < PublicController
  def index
    @artworks = Artwork.published.ordered.with_attached_image
  end

  # Unpublished works answer 404 to visitors; a signed-in admin sees them with a preview notice, and the
  # response is never cached.
  def show
    @artwork = Artwork.with_attached_image.includes(details: { image_attachment: :blob }).find_by!(slug: params[:slug])
    return if @artwork.published?
    raise ActiveRecord::RecordNotFound unless authenticated?

    @preview = true
    response.cache_control.replace(private: true, no_store: true)
  end
end
