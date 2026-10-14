module Admin
  # Contacto: the headline, the email and the Instagram account.
  class ContactController < SiteSettingsController
    self.permitted_attributes = %i[contact_headline email instagram_handle instagram_label]
  end
end
