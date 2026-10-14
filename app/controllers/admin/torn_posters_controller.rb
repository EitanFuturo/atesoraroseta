module Admin
  # Torn Posters: photos uploaded many at once, then edited together in one table (lugar, ciudad, año, texto
  # alternativo, publicada) and moved with ↑ ↓. Each photo also has its own page, to replace the image.
  class TornPostersController < BaseController
    include ImageUploads
    include Reordering

    before_action :set_poster, only: %i[show edit update destroy move]

    def index
      @torn_posters = posters
    end

    # There is no separate page to show a photo: its edit page is the one.
    def show
      redirect_to edit_admin_torn_poster_path(@poster)
    end

    # One unpublished poster per file. New posters go to the top of the list, so the files are saved last
    # first: the first file chosen ends up first.
    def create
      uploads = uploaded_images
      return redirect_to(admin_torn_posters_path, alert: t(".none"), status: :see_other) if uploads.empty?

      saved, rejected = TornPoster.transaction do
        save_uploads(uploads.reverse) { |upload| TornPoster.new(image: upload) }
      end

      flash[:notice] = t(".notice", count: saved.size) if saved.any?
      if rejected.any?
        flash[:alert] = t(".rejected", count: rejected.size)
        flash[:alert_details] = rejected.reverse
      end
      redirect_to admin_torn_posters_path, status: :see_other
    end

    # The table's "Guardar cambios", or "Marcar todas como publicadas" (which saves the table too). Nothing is
    # saved unless every row is valid.
    def bulk_update
      @torn_posters = posters
      changes = params.permit(torn_posters: [ :place, :city, :years, :alt, :published ]).fetch(:torn_posters, {})

      @torn_posters.each do |poster|
        poster.assign_attributes(changes[poster.id.to_s]) if changes.key?(poster.id.to_s)
        poster.published = true if publish_all?
      end

      if @torn_posters.map(&:valid?).all?
        TornPoster.transaction { @torn_posters.select(&:changed?).each(&:save!) }
        redirect_to admin_torn_posters_path, notice: t(publish_all? ? ".published_all" : ".notice"), status: :see_other
      else
        render :index, status: :unprocessable_content
      end
    end

    def edit
    end

    def update
      if @poster.update(poster_params)
        redirect_to admin_torn_posters_path(anchor: helpers.dom_id(@poster)), notice: t(".notice"), status: :see_other
      else
        discard_rejected_image(@poster, :image)
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      @poster.destroy!
      redirect_to admin_torn_posters_path, notice: t(".notice"), status: :see_other
    end

    # ↑ ↓ in the table; the page refreshes in place.
    def move
      direction = move_record(@poster)
      remember_moved(@poster, direction)
      redirect_to admin_torn_posters_path, notice: t(".#{direction}"), status: :see_other
    end

    private
      def posters
        TornPoster.ordered.with_attached_image.to_a
      end

      def set_poster
        @poster = TornPoster.find(params[:id])
      end

      def poster_params
        without_blank_images(params.expect(torn_poster: [ :place, :city, :years, :alt, :published, :image ]), :image)
      end

      def publish_all?
        params[:publish_all].present?
      end
  end
end
