module Admin
  # The pages that edit the settings record (Site.first_or_create!): Sobre mí, Contacto and Textos del sitio.
  # Each one permits only its own fields; an optional image can be removed ("Quitar esta imagen al guardar").
  # Not routed itself: AboutController, ContactController and SiteTextsController are.
  class SiteSettingsController < BaseController
    include ImageUploads

    # Set by each page: the attributes it edits, and which of them are images.
    class_attribute :permitted_attributes, instance_writer: false, default: []
    class_attribute :image_attributes, instance_writer: false, default: []

    before_action :set_site

    # There is nothing to show apart from the form.
    def show
      redirect_to action: :edit
    end

    def edit
    end

    def update
      @site.assign_attributes(site_params)
      remove_requested_images

      if @site.save
        redirect_to({ action: :edit }, notice: t("admin.site_settings.update.notice"), status: :see_other)
      else
        image_attributes.each { |name| discard_rejected_image(@site, name) }
        render :edit, status: :unprocessable_content
      end
    end

    private
      def set_site
        @site = Site.first_or_create!
      end

      def site_params
        without_blank_images(params.expect(site: permitted_attributes), *image_attributes)
      end

      # site[remove_portrait]=1 and the like, unless a new file was chosen for that image.
      def remove_requested_images
        image_attributes.each do |name|
          next unless params.dig(:site, :"remove_#{name}") == "1" && params.dig(:site, name).blank?

          @site.public_send(:"#{name}=", nil)
        end
      end
  end
end
