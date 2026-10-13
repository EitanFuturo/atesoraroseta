# A photo of a torn poster in the street, shown in the Torn Posters grid. Posters have no page of their own.
class TornPoster < ApplicationRecord
  include YearRange

  has_one_attached :image

  # New photos go to the top of the grid.
  acts_as_list add_new_at: :top

  normalizes :place, :city, :alt, with: ->(text) { text.strip }

  validates :image, presence: { message: :image_missing }

  scope :published, -> { where(published: true) }
  # The grid order: the admin's position, then the most recent (last) year, then creation.
  scope :ordered, -> { order(:position).order(YearRange.sort_year_node(arel_table).desc).order(:id) }
  scope :missing_alt, -> { where(alt: [ nil, "" ]) }

  # The photo's alt text, falling back to "Lugar, Ciudad" (or "" when both are blank).
  def alt_text
    alt.presence || [ place, city ].compact_blank.join(", ")
  end

  def alt_missing?
    alt.blank?
  end

  # "Ciudad · 2024", either part alone, or nil when both are blank (the hover label's second line).
  def meta_line
    [ city, years_label ].compact_blank.join(" · ").presence
  end

  # False when place, city and year are all blank: the tile then has no hover label at all.
  def labelled?
    place.present? || meta_line.present?
  end

  # The fragment id of the poster's tile on /torn-posters ("Ver en la web" links to /torn-posters#poster-<id>).
  def anchor
    "poster-#{id}"
  end
end
