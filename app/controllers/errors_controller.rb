# The error pages, reached through config.exceptions_app (config/initializers/error_pages.rb) in production,
# or directly at /404 and /500.
#
# - 404: in the site's layout, built like Contacto from the settings record; other formats get an empty 404.
#   If the page can't be built (the database is unavailable, say), the static public/404.html instead.
# - 500: the static public/500.html. Something has already failed, so it needs neither the database nor the
#   layout.
class ErrorsController < PublicController
  def not_found
    respond_to do |format|
      format.html { render status: :not_found }
      format.any { head :not_found }
    end
  rescue StandardError => error
    raise if performed?

    Rails.logger.error("The 404 page failed, showing public/404.html instead: #{error.class}: #{error.message}")
    render file: Rails.public_path.join("404.html"), layout: false, status: :not_found, content_type: "text/html"
  end

  def internal_error
    render file: Rails.public_path.join("500.html"), layout: false, status: :internal_server_error,
      content_type: "text/html"
  end
end
