module Admin
  # Thumbnails, sizes and warnings for the admin's image fields and lists.
  module ImagesHelper
    # The favicon's own minimum: its largest variant is 512 px square.
    ICON_MINIMUM = 512

    # The admin thumbnail (the :thumb variant, up to 320 px), drawn small. Decorative: the text next to
    # it names the record. Shows a placeholder when there is no image to draw.
    def admin_thumbnail(attachment, large: false)
      classes = [ "thumb", ("thumb--large" if large) ]

      if attachment.attached? && attachment.variable?
        image_tag attachment.variant(:thumb), alt: "", class: classes, loading: "lazy", decoding: "async"
      else
        tag.span t("admin.images.no_preview"), class: [ *classes, "thumb--missing" ]
      end
    end

    # "1179 × 1571 px", or nil while the size is unknown.
    def admin_image_dimensions(record, name)
      width, height = admin_image_size(record, name)
      t("admin.images.dimensions", width: width, height: height) if width && height
    end

    # True when the image was chosen in this form but isn't saved yet (the form came back with errors).
    def admin_image_pending?(attachment)
      attachment.attached? && attachment.attachment.new_record?
    end

    # The warnings about one image, as sentences: too small for large screens, or a size that couldn't
    # be read. kind: :icon checks the favicon against its own 512 px minimum and squareness instead.
    def admin_image_warnings(record, name, kind: :photo)
      attachment = record.public_send(name)
      return [] unless attachment.attached? && !admin_image_pending?(attachment)

      width, height = admin_image_size(record, name)
      return [ t("admin.images.unknown_size") ] unless width && height

      if kind == :icon
        admin_icon_warnings(width, height)
      elsif record.public_send(:"#{name}_low_resolution?")
        [ t("admin.images.low_resolution", long_side: [ width, height ].max, minimum: ImageAttachments::LOW_RESOLUTION_LONG_SIDE) ]
      else
        []
      end
    end

    # What file inputs accept: "image/jpeg,image/png,image/webp" (plus AVIF when this server can read it).
    def admin_image_accept
      ImageAttachments.accept
    end

    # "JPEG, PNG o WebP, hasta 25 MB."
    def admin_image_formats_hint
      t("admin.images.formats", formats: ImageAttachments.format_names, max_megabytes: ImageAttachments::MAX_BYTES / 1.megabyte)
    end

    private
      def admin_image_size(record, name)
        [ record.public_send(:"#{name}_width"), record.public_send(:"#{name}_height") ]
      end

      def admin_icon_warnings(width, height)
        warnings = []
        warnings << t("admin.images.icon_small", size: [ width, height ].min, minimum: ICON_MINIMUM) if [ width, height ].min < ICON_MINIMUM
        warnings << t("admin.images.icon_not_square", width: width, height: height) if width != height
        warnings
      end
  end
end
