# A detail photo of an artwork, shown in the artwork page's masonry, in its own order.
class ArtworkDetail < ApplicationRecord
  include ImageAttachments

  # Touching the artwork keeps its updated_at (cache keys, sitemap lastmod) in step with its details.
  belongs_to :artwork, inverse_of: :details, touch: true

  image_attachment :image, variants: %i[width], required: true

  # New details go to the end of their artwork's list.
  acts_as_list scope: :artwork

  normalizes :alt, with: ->(text) { text.strip }

  scope :missing_alt, -> { where(alt: [ nil, "" ]) }

  # The detail's alt text, falling back to "Título de la obra (n/N)".
  def alt_text
    alt.presence || "#{artwork.title} (#{number}/#{artwork.details.size})"
  end

  def alt_missing?
    alt.blank?
  end

  # The detail's place among its artwork's details, from 1.
  def number
    (artwork.details.index(self) || artwork.details.size) + 1
  end
end
