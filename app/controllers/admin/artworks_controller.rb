module Admin
  # Obras: the list in the public order, and each work's page with its details. Works are found by their
  # slug, which is their to_param (/admin/artworks/obra-de-muestra-01/edit).
  class ArtworksController < BaseController
    include ImageUploads
    include Reordering

    before_action :set_artwork, only: %i[show edit update destroy move]

    def index
      @artworks = Artwork.ordered.with_attached_image.includes(:details)
    end

    # There is no separate page to show a work: its edit page is the one.
    def show
      redirect_to edit_admin_artwork_path(@artwork)
    end

    def new
      @artwork = Artwork.new
    end

    def create
      @artwork = Artwork.new(artwork_params_for_create)

      if @artwork.save
        redirect_to edit_admin_artwork_path(@artwork), notice: t(".notice", title: @artwork.title), status: :see_other
      else
        discard_rejected_image(@artwork, :image)
        # Show the slug as it was sent, not the one validation generated: a slug generated from a blank
        # title ("obra") would otherwise look typed by hand and stop following the title.
        @artwork.slug = params.dig(:artwork, :slug).to_s
        render :new, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @artwork.update(artwork_params)
        redirect_to edit_admin_artwork_path(@artwork), notice: t(".notice"), status: :see_other
      else
        discard_rejected_image(@artwork, :image)
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @artwork.destroy!
      redirect_to admin_artworks_path, notice: t(".notice", title: @artwork.title), status: :see_other
    end

    # ↑ ↓ in the list. Back to the list it came from (/admin or /admin/artworks), so Turbo refreshes the
    # page in place.
    def move
      direction = move_record(@artwork)
      remember_moved(@artwork, direction)
      redirect_back_or_to admin_artworks_path, notice: t(".#{direction}", title: @artwork.title), status: :see_other
    end

    private
      def set_artwork
        @artwork = Artwork.with_attached_image.includes(details: { image_attachment: :blob }).find_by!(slug: params[:id])
      end

      def artwork_params
        attributes = params.expect(artwork: [ :title, :slug, :years, :medium, :dimensions, :description, :published, :image, :image_alt,
          details_attributes: [ [ :id, :alt ] ] ])
        without_blank_images(attributes, :image)
      end

      # The new-artwork form fills the slug from the title as it is typed. When that automatic slug is
      # already taken, the model makes it unique (-2, -3…) instead of refusing it: only a slug typed by
      # hand is kept as it is.
      def artwork_params_for_create
        attributes = artwork_params
        attributes[:slug] = "" if attributes[:slug].present? && attributes[:slug] == Artwork.slug_from(attributes[:title])
        attributes
      end
  end
end
