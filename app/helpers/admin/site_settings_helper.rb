module Admin
  # The fields of the settings pages (Sobre mí, Contacto, Textos del sitio).
  module SiteSettingsHelper
    # A text field of the settings record, with its label (es.yml), its hint (admin.site_settings.hints) and
    # "(obligatorio)" for the texts that can't be blank (Site::REQUIRED_TEXTS). as: :text_area for longer texts.
    def admin_site_field(form, attribute, as: :text_field, **options)
      hint = t("admin.site_settings.hints.#{attribute}", default: "").presence

      admin_field form, attribute, hint: hint, required: Site::REQUIRED_TEXTS.include?(attribute) do |aria|
        options = options.merge(rows: 3) if as == :text_area
        form.public_send(as, attribute, aria: aria, **options)
      end
    end
  end
end
