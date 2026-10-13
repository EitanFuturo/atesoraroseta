# The single settings record: every public text that isn't an artwork or a poster, plus the portrait,
# the default social image and the favicon.
#
# - Site.current: the stored record, or an unsaved one with the defaults, so public pages render before
#   seeding and a GET never writes.
# - Site.first_or_create!: what the admin edits (created with the defaults when missing).
class Site < ApplicationRecord
  # The default texts (config/site_defaults.yml), keyed by column name.
  DEFAULTS = YAML.load_file(Rails.root.join("config/site_defaults.yml"), aliases: true).each_value(&:freeze).freeze

  # Labels, headings and link texts that would leave an empty link or heading behind. Content
  # (intro, lead, SEO description, email, Instagram handle, portrait alt, 404 text) may be blank.
  REQUIRED_TEXTS = %i[
    wordmark nav_work_label nav_torn_posters_label nav_about_label nav_contact_label
    details_label previous_label next_label view_details_label view_detail_one_label
    year_label medium_label dimensions_label about_contact_link_label instagram_label
    not_found_title not_found_link_label
  ].freeze

  INSTAGRAM_HANDLE_FORMAT = /\A[a-z0-9._]{1,30}\z/
  INSTAGRAM_URL_PREFIX = %r{\A(?:https?://)?(?:[a-z0-9-]+\.)*instagram\.com/}i

  has_rich_text :about_body
  has_one_attached :portrait
  has_one_attached :og_image
  has_one_attached :favicon

  after_initialize :apply_defaults, if: :new_record?

  normalizes(*(DEFAULTS.keys.map(&:to_sym) - %i[email instagram_handle]), with: ->(text) { text.strip })
  normalizes :email, with: ->(email) { email.strip.presence }
  normalizes :instagram_handle, with: ->(handle) { Site.normalize_instagram_handle(handle) }

  validates(*REQUIRED_TEXTS, presence: true)
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :instagram_handle, format: { with: INSTAGRAM_HANDLE_FORMAT }, allow_blank: true
  validate :single_record, on: :create

  class << self
    def current
      first || new
    end

    # Accepts "usuario", "@usuario" or a pasted profile URL such as "https://www.instagram.com/usuario/?igsh=…",
    # and returns "usuario" (nil when blank).
    def normalize_instagram_handle(text)
      handle = text.to_s.strip.sub(INSTAGRAM_URL_PREFIX, "")
      handle = handle.split(%r{[/?#]}).first.to_s.delete_prefix("@")
      handle.downcase.presence
    end
  end

  # "Ver los 3 detalles", or the one-detail label for exactly 1.
  def view_details_text(count)
    count == 1 ? view_detail_one_label : view_details_label.to_s.gsub("%{count}", count.to_s)
  end

  # "https://www.instagram.com/usuario/", or nil without a handle.
  def instagram_url
    "https://www.instagram.com/#{instagram_handle}/" if instagram_handle.present?
  end

  # "@usuario", or nil without a handle.
  def instagram_at_handle
    "@#{instagram_handle}" if instagram_handle.present?
  end

  # The portrait's alt text; "" (decorative) when it has none.
  def portrait_alt_text
    portrait_alt.to_s
  end

  def portrait_alt_missing?
    portrait.attached? && portrait_alt.blank?
  end

  private
    def apply_defaults
      DEFAULTS.each do |attribute, value|
        self[attribute] = value if value.present? && self[attribute].nil?
      end
    end

    def single_record
      errors.add(:base, :site_already_exists) if Site.exists?
    end
end
