module Admin
  # The Obras list and form.
  module ArtworksHelper
    # The short warnings of the Obras list: a small main image, and alt texts that are missing.
    def admin_artwork_list_warnings(artwork)
      warnings = []
      warnings << t("admin.artworks.index.warnings.low_resolution") if artwork.image_low_resolution?
      warnings << t("admin.artworks.index.warnings.alt_missing") if artwork.alt_missing?

      details_without_alt = artwork.details.count(&:alt_missing?)
      if details_without_alt.positive?
        warnings << t("admin.artworks.index.warnings.details_alt_missing", count: details_without_alt)
      end

      warnings
    end
  end
end
