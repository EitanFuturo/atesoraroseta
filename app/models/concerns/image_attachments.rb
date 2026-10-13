# Image attachments with the rules of overview §4.2 and the variants of §4.5.
#
#   class Artwork < ApplicationRecord
#     include ImageAttachments
#     image_attachment :image, variants: %i[width og], required: true
#   end
#
# image_attachment declares has_one_attached with the variants of ImageVariants and adds:
# - validation of new uploads: JPEG, PNG or WebP (and AVIF when this libvips can read it), up to 25 MB;
# - analysis right after the record commits, so width and height exist before the first render;
# - <name>_width, <name>_height, <name>_aspect_ratio and <name>_low_resolution? (long side under 1600 px:
#   a warning for the admin, not a validation error).
module ImageAttachments
  extend ActiveSupport::Concern

  MAX_BYTES = 25.megabytes
  LOW_RESOLUTION_LONG_SIDE = 1600

  CONTENT_TYPES = { "image/jpeg" => "JPEG", "image/png" => "PNG", "image/webp" => "WebP" }.freeze
  AVIF = { "image/avif" => "AVIF" }.freeze

  # VIPS_OPERATION_BLOCKED: libvips 8.18 marks heifload untrusted when libheif is older than 1.23.2, and
  # Active Storage blocks untrusted operations, so ".avif" can be listed while every AVIF load fails.
  VIPS_OPERATION_BLOCKED = 32

  class << self
    # Tests set true or false; nil detects again.
    attr_writer :avif_supported

    # Whether this libvips can load AVIF uploads (evaluated after boot, once).
    def avif_supported?
      @avif_supported = detect_avif_support if @avif_supported.nil?
      @avif_supported
    end

    # { content type => format name } of the accepted uploads.
    def accepted_types
      avif_supported? ? CONTENT_TYPES.merge(AVIF) : CONTENT_TYPES
    end

    def content_types
      accepted_types.keys
    end

    # For file inputs: accept="image/jpeg,image/png,image/webp".
    def accept
      content_types.join(",")
    end

    # "JPEG, PNG o WebP" (or "JPEG, PNG, WebP o AVIF").
    def format_names
      accepted_types.values.to_sentence(two_words_connector: " o ", last_word_connector: " o ")
    end

    private
      def detect_avif_support
        Vips.get_suffixes.include?(".avif") &&
          (Vips::Introspect.get_yard("heifload").flags & VIPS_OPERATION_BLOCKED).zero?
      rescue Vips::Error
        false
      end
  end

  included do
    # { attachment name => responsive family (:width, :square, :portrait or nil) }, read by ResponsiveImage.
    class_attribute :image_attachment_families, instance_writer: false, default: {}
  end

  class_methods do
    def image_attachment(name, variants:, required: false)
      name = name.to_sym
      unknown = variants - ImageVariants::SETS
      raise ArgumentError, "Unknown variant sets #{unknown.inspect}" if unknown.any?

      has_one_attached(name) { |attachable| ImageVariants.define(attachable, variants) }
      self.image_attachment_families = image_attachment_families.merge(name => ImageVariants.family_in(variants))

      validates name, presence: { message: :image_missing } if required
      validate { validate_image_upload(name) }

      # Defined after has_one_attached, so it runs after the after_commit that uploads the file.
      after_commit(on: %i[create update]) { analyze_image_now(name) }

      define_method(:"#{name}_width") { image_metadata(name)["width"] }
      define_method(:"#{name}_height") { image_metadata(name)["height"] }

      # Width / height as a Float, or nil when unknown.
      define_method(:"#{name}_aspect_ratio") do
        width, height = image_metadata(name).values_at("width", "height")
        width.fdiv(height) if width.to_i.positive? && height.to_i.positive?
      end

      # True when the long side is under 1600 px; false when the size is unknown.
      define_method(:"#{name}_low_resolution?") do
        width, height = image_metadata(name).values_at("width", "height")
        width.present? && height.present? && [ width, height ].max < LOW_RESOLUTION_LONG_SIDE
      end
    end
  end

  private
    def image_metadata(name)
      attachment = public_send(name)
      attachment.attached? ? attachment.blob.metadata : {}
    end

    # Only new uploads are checked, so a record whose image was accepted before stays editable.
    def validate_image_upload(name)
      attachment = public_send(name)
      return unless attachment.attached? && attachment.attachment.new_record?

      blob = attachment.blob
      unless ImageAttachments.content_types.include?(blob.content_type)
        errors.add(name, :image_content_type, formats: ImageAttachments.format_names)
      end

      if blob.byte_size.to_i > MAX_BYTES
        errors.add(name, :image_too_large, max_megabytes: MAX_BYTES / 1.megabyte)
      end
    end

    # Reads width and height now instead of waiting for Active Storage's AnalyzeJob. When this fails,
    # the blob stays unanalyzed and the AnalyzeJob that Active Storage enqueues next tries again.
    def analyze_image_now(name)
      attachment = public_send(name)
      return unless attachment.attached?

      blob = attachment.blob
      blob.analyze unless blob.analyzed?
    rescue StandardError => error
      Rails.logger.warn("Analyzing #{self.class.name}##{name} (blob #{blob&.id}) failed, the AnalyzeJob will retry: " \
        "#{error.class}: #{error.message}")
    end
end
