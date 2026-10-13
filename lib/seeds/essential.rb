module Seeds
  # What every environment gets, production included: the settings row with the production default texts
  # (config/site_defaults.yml) and the admin user through AdminAccount.sync. Nothing else, and never a
  # bracketed placeholder.
  class Essential
    def initialize(credentials: Rails.application.credentials, env: ENV, output: $stdout)
      @credentials = credentials
      @env = env
      @output = output
    end

    def run
      site = Site.first_or_create!
      @output.puts(site.previously_new_record? ? "Ajustes del sitio: creados con los textos por defecto." : "Ajustes del sitio: ya existían.")
      @output.puts AdminAccount.sync(credentials: @credentials, env: @env).message
    end
  end
end
