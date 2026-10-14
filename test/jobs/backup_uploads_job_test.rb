require "test_helper"
require "fugit"
require_relative "../test_helpers/fake_spaces"

class BackupUploadsJobTest < ActiveJob::TestCase
  include FakeSpaces

  setup do
    [ ActiveStorage::Attachment, ActiveStorage::VariantRecord, ActiveStorage::Blob ].each(&:delete_all)
    @blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "small.png")
    @log = StringIO.new
    @logger, BackupUploadsJob.logger = BackupUploadsJob.logger, ActiveSupport::Logger.new(@log)
  end

  teardown { BackupUploadsJob.logger = @logger }

  test "the job copies what the bucket lacks, through the configured bucket, and logs the counts" do
    objects = {}

    with_fake_spaces(objects) { BackupUploadsJob.perform_now }

    assert_equal [ "uploads/#{@blob.key}" ], objects.keys
    assert_includes @log.string, "Copia de seguridad de los archivos subidos: 1 copiados a Spaces"
    assert_no_enqueued_jobs
  end

  test "when a file can't be copied the job is tried again 15 minutes later" do
    File.binwrite(@blob.service.path_for(@blob.key), "damaged")

    freeze_time do
      with_fake_spaces { BackupUploadsJob.perform_now }

      assert_enqueued_jobs 1, only: BackupUploadsJob
      retry_at = enqueued_jobs.first[:at]
      assert_operator retry_at, :>=, 15.minutes.from_now.to_f
      assert_operator retry_at, :<=, 18.minutes.from_now.to_f
    end
  end

  test "it runs every night at 03:30 in Madrid, in summer and in winter" do
    task = YAML.load_file(Rails.root.join("config/recurring.yml")).dig("production", "backup_uploads")
    schedule = Fugit.parse(task["schedule"], multi: :fail)

    assert_equal BackupUploadsJob, task["class"].constantize
    assert_instance_of Fugit::Cron, schedule, "Solid Queue only accepts schedules that parse to a cron"
    assert_equal Time.utc(2026, 7, 2, 1, 30), schedule.next_time(EtOrbi.make_time("2026-07-01 12:00:00 UTC")).utc
    assert_equal Time.utc(2026, 12, 2, 2, 30), schedule.next_time(EtOrbi.make_time("2026-12-01 12:00:00 UTC")).utc
  end
end
