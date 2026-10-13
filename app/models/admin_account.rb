# The single admin login, kept in step with the encrypted credentials (admin.email, admin.password).
# ADMIN_EMAIL and ADMIN_PASSWORD, when set, override them (CI, the deploy rehearsal).
#
#   AdminAccount.sync # => #<data AdminAccount::Result status=:created, message="Admin: …">
#
# It creates the user, or changes its password when it differs and then deletes all of that user's
# sessions. With no email or password anywhere (no master key, no admin entry yet) it only warns, so it
# never fails bin/setup, the seeds or a production boot. It never prints or logs the password.
#
# Runs from bin/rails admin:sync, the seeds and bin/docker-entrypoint (every production boot).
class AdminAccount
  # status: :created, :updated, :unchanged, :skipped (nothing to sync) or :invalid (not saved).
  Result = Data.define(:status, :message) do
    def warning?
      status.in?(%i[skipped invalid])
    end
  end

  def self.sync(credentials: Rails.application.credentials, env: ENV)
    new(credentials: credentials, env: env).sync
  end

  def initialize(credentials:, env:)
    @credentials = credentials
    @env = env
  end

  def sync
    email = @env["ADMIN_EMAIL"].presence || credential(:email)
    password = @env["ADMIN_PASSWORD"].presence || credential(:password)
    return skipped(email, password) if email.blank? || password.blank?

    user = User.find_by(email_address: email)

    if user.nil?
      create(email, password)
    elsif user.authenticate(password)
      Result.new(:unchanged, "Admin: #{user.email_address} sin cambios.")
    else
      change_password(user, password)
    end
  end

  private
    def credential(key)
      @credentials.dig(:admin, key).presence&.to_s
    rescue StandardError => error # e.g. a master key that doesn't match the file
      @unreadable = error.class.name
      nil
    end

    def create(email, password)
      user = User.new(email_address: email, password: password)
      return invalid(user) unless user.save

      Result.new(:created, "Admin: usuario #{user.email_address} creado.")
    end

    def change_password(user, password)
      closed = User.transaction do
        user.update!(password: password)
        user.sessions.destroy_all.size
      end

      Result.new(:updated, "Admin: contraseña de #{user.email_address} actualizada; " \
        "#{closed} #{closed == 1 ? "sesión cerrada" : "sesiones cerradas"}.")
    rescue ActiveRecord::RecordInvalid
      invalid(user)
    end

    def skipped(email, password)
      missing = []
      missing << "el correo (admin.email o ADMIN_EMAIL)" if email.blank?
      missing << "la contraseña (admin.password o ADMIN_PASSWORD)" if password.blank?
      message = "Admin: falta #{missing.to_sentence(two_words_connector: " y ", last_word_connector: " y ")}; " \
        "no se crea ni se cambia ningún usuario."
      message += " No se pudieron leer las credenciales (#{@unreadable})." if @unreadable

      Result.new(:skipped, message)
    end

    def invalid(user)
      Result.new(:invalid, "Admin: no se ha guardado #{user.email_address}: #{user.errors.full_messages.to_sentence}.")
    end
end
