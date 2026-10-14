# The off-server backups in the Spaces bucket (DEPLOY.md, "Backups"). Litestream replicates the database
# by itself; these tasks handle the uploaded files and report on both. None of them deletes anything.
namespace :backup do
  desc "Copy now every uploaded file the Spaces backups bucket doesn't have yet to uploads/<key>, " \
       "as the nightly BackupUploadsJob does. Never deletes anything."
  task uploads: :environment do
    summary = BackupUploads.new.backup
    summary.failed? ? abort(summary.message) : puts(summary.message)
  rescue BackupBucket::NotConfigured => error
    abort error.message
  end

  desc "Download from the Spaces backups bucket every uploaded file missing on disk (after restoring " \
       "the database). Never overwrites or deletes anything."
  task restore_uploads: :environment do
    summary = BackupUploads.new.restore
    summary.failed? ? abort(summary.message) : puts(summary.message)
  rescue BackupBucket::NotConfigured => error
    abort error.message
  end

  desc "Show what the backups hold: the uploaded files on disk and in Spaces, and Litestream's latest " \
       "position in the bucket."
  task status: :environment do
    puts BackupUploads.new.status
  rescue BackupBucket::NotConfigured => error
    abort error.message
  end
end
