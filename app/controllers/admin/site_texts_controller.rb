module Admin
  # Textos del sitio: the wordmark and the menu, the Torn Posters intro, the labels of the artwork page, the
  # description and image for search engines and social networks, the favicon, and the 404 page.
  class SiteTextsController < SiteSettingsController
    self.permitted_attributes = %i[
      wordmark nav_work_label nav_torn_posters_label nav_about_label nav_contact_label
      torn_posters_intro
      details_label previous_label next_label view_details_label view_detail_one_label year_label medium_label dimensions_label
      seo_description og_image
      favicon
      not_found_title not_found_text not_found_link_label
    ]
    self.image_attributes = %i[og_image favicon]
  end
end
