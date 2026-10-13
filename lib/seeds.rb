# The seeds (db/seeds.rb).
#
# - Every environment, production included (Seeds::Essential): the settings row with the default texts,
#   and the admin user from the encrypted credentials or ADMIN_EMAIL / ADMIN_PASSWORD (warns and goes on
#   without them).
# - Development only (Seeds::SampleContent): the design canvas's sample content, placeholders included.
#
# Running them again changes nothing.
module Seeds
  # process_variants: false leaves the sample content's variants to the job queue (tests).
  def self.run(environment: Rails.env, credentials: Rails.application.credentials, env: ENV, output: $stdout,
    process_variants: true)
    Essential.new(credentials: credentials, env: env, output: output).run
    SampleContent.new(output: output, process_variants: process_variants).run if environment.to_s == "development"
  end
end
