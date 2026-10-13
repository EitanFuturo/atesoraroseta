# The nightly copy of the uploaded files to the Spaces backups bucket (config/recurring.yml, at 03:30
# Madrid time). It copies only what the bucket doesn't have yet and never deletes anything; see
# BackupUploads. bin/rails backup:uploads does the same copy right away.
class BackupUploadsJob < ApplicationJob
  queue_as :default

  # Some files couldn't be copied (Spaces unreachable for a while, say): try again twice, 15 minutes
  # apart. Files copied on the first attempt are skipped.
  retry_on BackupUploads::Incomplete, wait: 15.minutes, attempts: 3

  def perform
    summary = BackupUploads.new.backup
    raise BackupUploads::Incomplete, summary.message if summary.failed?

    logger.info(summary.message)
    summary
  end
end
