module Admin
  # Image uploads in admin forms. Files arrive as signed blob ids (Active Storage direct uploads), or as the
  # files themselves when JavaScript didn't run; models validate both alike.
  module ImageUploads
    private
      # The files of a multiple field named images[], in the order they were chosen.
      def uploaded_images
        params.permit(images: []).fetch(:images, []).compact_blank
      end

      # Saves one record per upload, building each with the block. Returns the saved records and, for each
      # rejected file, a sentence saying which one and why.
      def save_uploads(uploads)
        saved = []
        rejected = []

        uploads.each do |upload|
          record = yield(upload)

          if record.save
            saved << record
          else
            rejected << t("admin.uploads.rejected", name: record.image.filename.to_s, reasons: record.errors.full_messages.to_sentence)
            discard_rejected_image(record, :image)
          end
        rescue ActiveSupport::MessageVerifier::InvalidSignature
          rejected << t("admin.uploads.rejected_unknown")
        end

        [ saved, rejected ]
      end

      # A direct upload the record refused (wrong type, too large) is deleted: nothing will ever use it.
      # Only a blob that no record uses, so an existing image is never touched.
      def discard_rejected_image(record, name)
        attachment = record.public_send(name)
        return unless attachment.attached? && attachment.attachment.new_record? && record.errors[name].any?

        blob = attachment.blob
        blob.purge_later if blob.persisted? && !blob.attachments.exists?
      end

      # The parameters of a single image field, without an empty value: assigning "" would remove the
      # current image.
      def without_blank_images(attributes, *names)
        names.each { |name| attributes.delete(name) if attributes[name].blank? }
        attributes
      end
  end
end
