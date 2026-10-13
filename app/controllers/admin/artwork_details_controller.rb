module Admin
  # A work's detail photos, on the work's edit page: added several at once and deleted one by one. Their alt
  # texts are saved with the work's own form (Artwork accepts_nested_attributes_for :details).
  class ArtworkDetailsController < BaseController
    include ImageUploads

    before_action :set_artwork
    before_action :set_detail, only: :destroy

    # One detail per chosen file, in the order chosen, after the existing ones.
    def create
      uploads = uploaded_images
      return redirect_to(details_section, alert: t(".none"), status: :see_other) if uploads.empty?

      saved, rejected = save_uploads(uploads) { |upload| @artwork.details.build(image: upload) }
      flash[:notice] = t(".notice", count: saved.size) if saved.any?
      if rejected.any?
        flash[:alert] = t(".rejected", count: rejected.size)
        flash[:alert_details] = rejected
      end

      redirect_to details_section, status: :see_other
    end

    def destroy
      @detail.destroy!
      redirect_to details_section, notice: t(".notice"), status: :see_other
    end

    private
      def set_artwork
        @artwork = Artwork.find_by!(slug: params[:artwork_id])
      end

      def set_detail
        @detail = @artwork.details.find(params[:id])
      end

      def details_section
        edit_admin_artwork_path(@artwork, anchor: "detalles")
      end
  end
end
