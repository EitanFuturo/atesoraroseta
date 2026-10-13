require "io/console" # IO#noecho

# Writes admin.email and admin.password into the encrypted credentials (config/credentials.yml.enc),
# keeping the rest of the file, comments included, and replacing an existing admin: block. The next
# deploy, or bin/rails admin:sync, applies them. It never prints the password.
#
#   bin/rails admin:credentials                                    # asks, without echoing the password
#   ADMIN_EMAIL=… ADMIN_PASSWORD=… bin/rails admin:credentials      # no questions
class AdminCredentials
  DEFAULT_EMAIL = "admin@atesoraroseta.com"
  MINIMUM_PASSWORD_LENGTH = 12
  MAXIMUM_PASSWORD_BYTES = 72 # bcrypt's limit, which has_secure_password enforces
  ATTEMPTS = 3
  SAVED = "Guardado. Despliega para aplicarlo en producción."

  # A message for the person running the task; never contains the password.
  class Error < StandardError; end

  # Prompts (interactive) or reads ADMIN_EMAIL / ADMIN_PASSWORD, writes, and says so.
  def self.run(credentials: Rails.application.credentials, env: ENV, input: $stdin, output: $stdout, interactive: input.tty?)
    new(credentials: credentials).run(env: env, input: input, output: output, interactive: interactive)
  end

  # Returns +content+ with a single admin: block holding +email+ and +password+: an existing top-level
  # admin: block is replaced where it was, otherwise the block is appended.
  def self.replace_admin_block(content, email:, password:)
    block = { "admin" => { "email" => email, "password" => password } }.to_yaml(line_width: -1).delete_prefix("---\n")
    lines = content.lines
    output = []
    inserted = false
    index = 0

    while index < lines.size
      if lines[index].match?(/\Aadmin:(\s|\z)/)
        finish = index + 1
        finish += 1 while finish < lines.size && (lines[finish].match?(/\A[ \t]/) || lines[finish].strip.empty?)
        finish -= 1 while finish > index + 1 && lines[finish - 1].strip.empty? # keep the blank lines after it
        output.concat(block.lines) unless inserted
        inserted = true
        index = finish
      else
        output << lines[index]
        index += 1
      end
    end

    unless inserted
      output[-1] = "#{output[-1]}\n" if output.any? && !output[-1].end_with?("\n")
      output << "\n" if output.any? && output[-1].strip.present?
      output.concat(block.lines)
    end

    output.join
  end

  def initialize(credentials: Rails.application.credentials)
    @credentials = credentials
  end

  def run(env:, input:, output:, interactive:)
    if env["ADMIN_EMAIL"].present? && env["ADMIN_PASSWORD"].present?
      write(email: env["ADMIN_EMAIL"], password: env["ADMIN_PASSWORD"])
    elsif interactive
      prompt_and_write(input, output)
    else
      raise Error, "Define ADMIN_EMAIL y ADMIN_PASSWORD, o ejecuta la tarea en una terminal."
    end

    output.puts SAVED
  end

  # The admin email stored now, or the default.
  def current_email
    @credentials.dig(:admin, :email).presence&.to_s || DEFAULT_EMAIL
  rescue StandardError
    DEFAULT_EMAIL
  end

  def write(email:, password:)
    email = email.to_s.strip
    check_email!(email)
    check_password!(password)
    raise Error, "Falta la clave maestra (config/master.key o RAILS_MASTER_KEY)." unless @credentials.key?
    raise Error, "No existe #{@credentials.content_path}." unless @credentials.content_path.exist?

    # A key that doesn't match raises here, before anything is written.
    content = @credentials.read
    updated = self.class.replace_admin_block(content, email: email, password: password)
    verify!(content, updated, email, password)
    @credentials.write(updated)
  end

  private
    def prompt_and_write(input, output)
      default = current_email
      output.print "Correo electrónico [#{default}]: "
      email = input.gets.to_s.strip.presence || default

      ATTEMPTS.times do
        output.print "Contraseña (mínimo #{MINIMUM_PASSWORD_LENGTH} caracteres): "
        password = read_secret(input, output)
        output.print "Repite la contraseña: "
        confirmation = read_secret(input, output)

        problem = password_problem(password) || ("Las contraseñas no coinciden." if password != confirmation)
        return write(email: email, password: password) if problem.nil?

        output.puts problem
      end

      raise Error, "Demasiados intentos; no se ha guardado nada."
    end

    def read_secret(input, output)
      line = input.respond_to?(:noecho) && input.tty? ? input.noecho(&:gets) : input.gets
      output.puts
      line.to_s.chomp
    end

    def check_email!(email)
      raise Error, "El correo electrónico no es válido." unless email.match?(URI::MailTo::EMAIL_REGEXP)
    end

    def check_password!(password)
      problem = password_problem(password)
      raise Error, problem if problem
    end

    def password_problem(password)
      if password.to_s.length < MINIMUM_PASSWORD_LENGTH
        "La contraseña debe tener al menos #{MINIMUM_PASSWORD_LENGTH} caracteres."
      elsif password.to_s.bytesize > MAXIMUM_PASSWORD_BYTES
        "La contraseña puede tener como máximo #{MAXIMUM_PASSWORD_BYTES} bytes."
      end
    end

    # Writes nothing unless the new file parses, holds exactly the new admin entry and keeps every other key.
    def verify!(content, updated, email, password)
      before = parse(content)
      after = parse(updated)

      unless after.is_a?(Hash) && after["admin"] == { "email" => email, "password" => password } &&
          after.except("admin") == before.except("admin")
        raise Error, "No se ha podido preparar el archivo de credenciales; no se ha guardado nada."
      end
    end

    def parse(text)
      YAML.safe_load(text, aliases: true, permitted_classes: [ Symbol, Date, Time ]) || {}
    rescue Psych::Exception
      raise Error, "El archivo de credenciales no es YAML válido; no se ha guardado nada."
    end
end
