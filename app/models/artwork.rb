class Artwork < ApplicationRecord
  include ImageAttachments
  include YearRange

  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  # Used when a title has no letters or digits to build a slug from.
  FALLBACK_SLUG = "obra"

  image_attachment :image, variants: %i[width og], required: true
  has_rich_text :description
  has_many :details, -> { order(:position) }, class_name: "ArtworkDetail", dependent: :destroy, inverse_of: :artwork
  # The admin saves the details' alt texts with the work's own form. Existing details only: new ones come
  # from uploads, one detail per file.
  accepts_nested_attributes_for :details, reject_if: ->(attributes) { attributes[:id].blank? }

  # New works go to the top of the Obra grid.
  acts_as_list add_new_at: :top

  normalizes :title, :medium, :dimensions, :image_alt, with: ->(text) { text.strip }
  normalizes :slug, with: ->(slug) { slug.strip.downcase }

  before_validation :generate_slug, if: -> { slug.blank? }

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT, message: :invalid_slug, allow_blank: true }

  scope :published, -> { where(published: true) }
  # The Obra order: the admin's position, then the most recent (last) year, then creation.
  # Built from Arel nodes so it can be reversed (.last, .reverse_order).
  scope :ordered, -> { order(:position).order(YearRange.sort_year_node(arel_table).desc).order(:id) }
  scope :missing_alt, -> { where(image_alt: [ nil, "" ]) }

  # Public URLs use the stored slug: artwork_path(artwork) is "/obra/<slug>".
  # The stored value, so a form re-rendered with an invalid new slug still posts to a working URL.
  def to_param
    slug_in_database.presence || super
  end

  # The published work before this one in the Obra order, or nil for the first. No wrap-around.
  # Works for an unpublished work too (the admin preview): its neighbours are the published works around it.
  def previous
    neighbours.first
  end

  # The published work after this one in the Obra order, or nil for the last. No wrap-around.
  def next
    neighbours.last
  end

  # The image's alt text, falling back to the title.
  def alt_text
    image_alt.presence || title
  end

  # True when the image has no alt text of its own (the admin flags these).
  def alt_missing?
    image_alt.blank?
  end

  # "2024 · Técnica", either part alone, or nil when both are blank (the tile's hover label).
  def meta_line
    [ years_label, medium ].compact_blank.join(" · ").presence
  end

  # The description as plain text, cut to about +limit+ characters, falling back to
  # "Título, 2024. Técnica." when there is no description.
  def meta_description(limit: 155)
    text = rich_text_description&.to_plain_text.to_s.squish

    if text.present?
      text.truncate(limit, separator: " ", omission: "…")
    else
      [ [ title, years_label ].compact_blank.join(", "), medium ].compact_blank
        .map { |part| part.end_with?(".") ? part : "#{part}." }.join(" ")
    end
  end

  def reload(*)
    @neighbours = nil
    super
  end

  private
    def generate_slug
      base = title.to_s.parameterize.presence || FALLBACK_SLUG
      candidate = base
      suffix = 1

      while Artwork.where.not(id: id).exists?(slug: candidate)
        suffix += 1
        candidate = "#{base}-#{suffix}"
      end

      self.slug = candidate
    end

    def neighbours
      @neighbours ||= begin
        ids = Artwork.published.or(Artwork.where(id: id)).ordered.pluck(:id)
        index = ids.index(id)

        if index.nil?
          [ nil, nil ]
        else
          previous_id = ids[index - 1] if index.positive?
          next_id = ids[index + 1]
          works = Artwork.where(id: [ previous_id, next_id ].compact).index_by(&:id)
          [ works[previous_id], works[next_id] ]
        end
      end
    end
end
