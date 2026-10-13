module Admin
  # The admin layout: page title, menu and links that open the public site in a new tab.
  module LayoutHelper
    # "Obras — Panel de atesoraroseta". Views set the first part with content_for(:title).
    def admin_page_title
      [ content_for(:title), t("admin.layout.title", wordmark: admin_site.wordmark) ].compact_blank.join(" — ")
    end

    # The settings record as the public site shows it (an unsaved default before seeding).
    def admin_site
      @admin_site ||= Site.current
    end

    # The menu: [label, path, section] per entry. A section groups the controllers of one menu entry.
    def admin_nav_items
      [
        [ Artwork.model_name.human(count: 2), admin_artworks_path, :artworks ]
      ]
    end

    # A menu link, marked aria-current="page" on every page of its section.
    def admin_nav_link(label, path, section)
      link_to label, path, aria: { current: ("page" if admin_section == section) }
    end

    # The menu section of the current page.
    def admin_section
      case controller_name
      when "artworks", "artwork_details" then :artworks
      else controller_name.to_sym
      end
    end

    # A link to the public site, opened in a new tab so the panel stays open. Screen readers hear that
    # it opens a new tab; the arrow is decorative.
    def admin_external_link(label, url, **options)
      link_to url, target: "_blank", rel: "noopener", **options do
        safe_join([ label, " ", tag.span("↗", aria: { hidden: true }), tag.span(" #{t("admin.layout.new_tab")}", class: "visually-hidden") ])
      end
    end
  end
end
