# Active Storage's direct uploads (POST /rails/active_storage/direct_uploads) only serve the admin's image
# fields, so they require login like every /admin route. Left open, anyone could store files on the server
# and get a signed id to serve them from the site's own address.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    include Authentication

    private
      # The uploader is a script expecting JSON, so answer 401 instead of redirecting to the login page.
      def request_authentication
        head :unauthorized
      end
  end
end
