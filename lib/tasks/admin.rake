namespace :admin do
  desc "Create the admin user, or update its password, from the credentials (admin.email, admin.password) " \
       "or ADMIN_EMAIL / ADMIN_PASSWORD. Never fails: without either it only warns."
  task sync: :environment do
    result = AdminAccount.sync
    result.warning? ? warn(result.message) : puts(result.message)
  end

  desc "Store the admin email and password in config/credentials.yml.enc (asks without echoing the password, " \
       "or reads ADMIN_EMAIL / ADMIN_PASSWORD). Deploy, or run admin:sync, to apply them."
  task credentials: :environment do
    AdminCredentials.run
  rescue AdminCredentials::Error => error
    abort error.message
  end
end
