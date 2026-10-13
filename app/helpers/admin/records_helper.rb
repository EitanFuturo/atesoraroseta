module Admin
  # Badges and "Ver en la web" links for artworks and posters.
  module RecordsHelper
    # "Publicada" or "Borrador".
    def admin_published_badge(record)
      if record.published?
        tag.span t("admin.records.published"), class: "badge badge--published"
      else
        tag.span t("admin.records.draft"), class: "badge badge--draft"
      end
    end

    # "Ver en la web ↗" in a new tab. An unpublished record that a logged-in admin can preview (an
    # artwork) links to its preview; one that has no public place yet (a poster) is greyed out, unlinked.
    def admin_view_on_site_link(path, published: true, previewable: true)
      if published
        admin_external_link t("admin.shared.view_on_site"), path
      elsif previewable
        admin_external_link t("admin.shared.preview_on_site"), path
      else
        tag.span t("admin.shared.unpublished_on_site"), class: "view-on-site--unpublished"
      end
    end
  end
end
