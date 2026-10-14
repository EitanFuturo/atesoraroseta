module Admin
  # The Torn Posters table and page.
  module TornPostersHelper
    # "Calle de Toledo, Madrid", from the saved values, or a stand-in when both are blank.
    def admin_poster_label(poster)
      [ poster.attribute_in_database(:place), poster.attribute_in_database(:city) ].compact_blank.join(", ").presence ||
        t("admin.torn_posters.unnamed")
    end

    # The saved alt text is blank: say what the public page uses instead (lugar and ciudad, or nothing).
    def admin_poster_alt_warning(poster)
      return if poster.attribute_in_database(:alt).present?

      current = [ poster.attribute_in_database(:place), poster.attribute_in_database(:city) ].compact_blank.join(", ")
      current.present? ? t("admin.torn_posters.alt_missing", current: current) : t("admin.torn_posters.alt_missing_decorative")
    end

    # The errors of every row, as "Foto 3: …" lines linked to their fields.
    def admin_poster_errors(posters)
      posters.each_with_index.flat_map do |poster, index|
        poster.errors.map do |error|
          link_to t("admin.torn_posters.index.error_line", number: index + 1, message: error.full_message),
            "#torn_posters_#{poster.id}_#{error.attribute}"
        end
      end
    end
  end
end
