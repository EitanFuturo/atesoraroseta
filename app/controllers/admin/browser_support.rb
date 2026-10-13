module Admin
  # The panel needs a modern browser (import maps, ES modules, custom elements for the editor). Older
  # browsers get a short page in Spanish instead of a half-working panel. Rails' default block would
  # render public/406-unsupported-browser.html, which the public site doesn't ship.
  module BrowserSupport
    extend ActiveSupport::Concern

    included do
      allow_browser versions: :modern, block: :render_unsupported_browser
    end

    private
      def render_unsupported_browser
        render "admin/unsupported_browser", layout: false, status: :not_acceptable
      end
  end
end
