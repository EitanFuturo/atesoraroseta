module Admin
  # Sobre mí: the lead, the text, the portrait with its alt text, and the link to Contacto.
  class AboutController < SiteSettingsController
    self.permitted_attributes = %i[about_lead about_body portrait portrait_alt about_contact_link_label]
    self.image_attributes = %i[portrait]
  end
end
