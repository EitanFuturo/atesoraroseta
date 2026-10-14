module Admin
  # Labelled fields with their hint and their errors, linked for screen readers (aria-describedby).
  module FormsHelper
    # A field: label, optional hint, the input the block renders, and the attribute's errors. The block gets
    # the ARIA options for its input:
    #
    #   <%= admin_field form, :title, required: true do |aria| %>
    #     <%= form.text_field :title, aria: aria %>
    #   <% end %>
    def admin_field(form, attribute, label: nil, hint: nil, required: false, &block)
      errors = admin_errors_for(form, attribute)
      hint_id = "#{form.field_id(attribute)}_hint" if hint
      error_id = "#{form.field_id(attribute)}_error" if errors.any?
      aria = { describedby: [ hint_id, error_id ].compact.join(" ").presence, invalid: (true if errors.any?) }.compact

      tag.div class: [ "field", ("field--invalid" if errors.any?) ] do
        safe_join([
          form.label(attribute, admin_label_text(form, attribute, label, required)),
          (tag.p(hint, class: "hint", id: hint_id) if hint),
          capture(aria, &block),
          (tag.p(errors.to_sentence(locale: :es), class: "field-error", id: error_id) if errors.any?)
        ].compact)
      end
    end

    # The attribute's full error messages ("Título no puede estar en blanco").
    def admin_errors_for(form, attribute)
      form.object.respond_to?(:errors) ? form.object.errors.full_messages_for(attribute) : []
    end

    # "Título", or "Título (obligatorio)".
    def admin_label_text(form, attribute, label, required)
      text = label || form.object.class.human_attribute_name(attribute)
      required ? "#{text} #{t("admin.forms.required")}" : text
    end

    # The messages of the upload controller (JavaScript), in Spanish. %{name} and %{size} are filled in there.
    def admin_upload_messages
      {
        tooLarge: t("admin.uploads.too_large", max: ImageAttachments::MAX_BYTES / 1.megabyte, name: "%{name}", size: "%{size}"),
        wrongType: t("admin.uploads.wrong_type", formats: ImageAttachments.format_names, name: "%{name}"),
        ready: t("admin.uploads.ready"),
        uploading: t("admin.uploads.uploading"),
        done: t("admin.uploads.done"),
        failed: t("admin.uploads.failed", name: "%{name}")
      }
    end

    # The data attributes of an element wrapping an upload field (see upload_controller.js).
    def admin_upload_data
      {
        controller: "upload",
        upload_max_bytes_value: ImageAttachments::MAX_BYTES,
        upload_accept_value: admin_image_accept,
        upload_messages_value: admin_upload_messages.to_json,
        action: %w[
          direct-upload:initialize->upload#register direct-upload:start->upload#start
          direct-upload:progress->upload#progress direct-upload:error->upload#error direct-upload:end->upload#end
        ].join(" ")
      }
    end

    # The data attributes of a page whose forms are saved separately (see unsaved_changes_controller.js).
    # dirty: the page came back with errors, so what its main form shows isn't saved yet.
    def admin_unsaved_changes_data(dirty: false)
      { controller: "unsaved-changes", unsaved_changes_message_value: t("admin.forms.unsaved_changes"), unsaved_changes_dirty_value: dirty }
    end
  end
end
