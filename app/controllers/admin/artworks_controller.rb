module Admin
  # Obras: the list in the public order, and each work's page with its details.
  class ArtworksController < BaseController
    def index
      @artworks = Artwork.ordered.with_attached_image.includes(:details)
    end
  end
end
