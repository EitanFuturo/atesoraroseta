# The single settings record: every public text that isn't an artwork or a poster.
# Defaults live in config/site_defaults.yml; blank means "not set yet".
# Rich text (about_body) and attachments (portrait, og_image, favicon) live in their own tables.
class CreateSites < ActiveRecord::Migration[8.1]
  def change
    create_table :sites do |t|
      t.string :wordmark
      t.string :nav_work_label
      t.string :nav_torn_posters_label
      t.string :nav_about_label
      t.string :nav_contact_label
      t.text :torn_posters_intro
      t.string :details_label
      t.string :previous_label
      t.string :next_label
      t.string :view_details_label
      t.string :view_detail_one_label
      t.string :year_label
      t.string :medium_label
      t.string :dimensions_label
      t.text :seo_description
      t.text :about_lead
      t.string :portrait_alt
      t.string :about_contact_link_label
      t.string :contact_headline
      t.string :email
      t.string :instagram_handle
      t.string :instagram_label
      t.string :not_found_title
      t.text :not_found_text
      t.string :not_found_link_label

      t.timestamps
    end
  end
end
