# The Torn Posters grid. Posters have no page of their own; each tile's id is its anchor (poster-<id>).
class TornPostersController < PublicController
  def index
    @posters = TornPoster.published.ordered.with_attached_image
  end
end
