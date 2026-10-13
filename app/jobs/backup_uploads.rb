# The off-server copy of the uploaded files: every Active Storage blob, the originals and their variants,
# kept in the backups bucket at uploads/<blob key>.
#
#   BackupUploads.new.backup   # copies the files the bucket doesn't have yet (nightly: BackupUploadsJob)
#   BackupUploads.new.restore  # downloads the files the disk is missing, after a database restore
#   BackupUploads.new.status   # counts on both sides, plus Litestream's latest position in db/
#
# It never deletes anything, in the bucket or on disk. A file removed in the admin stays in the bucket,
# so a database restored to any earlier moment still finds every image it refers to. Both directions
# check the files against the blob's checksum: a damaged file is reported, never copied.
class BackupUploads
  PREFIX = "uploads/"
  DATABASE_PREFIX = "db/"

  # Raised by BackupUploadsJob when some files couldn't be copied, so the job is retried.
  class Incomplete < StandardError; end

  # direction: :backup or :restore. counts: how many blobs had each outcome. bytes: the size transferred.
  Summary = Data.define(:direction, :counts, :bytes) do
    def failed?
      counts[:failed].positive?
    end

    def message
      size = ActiveSupport::NumberHelper.number_to_human_size(bytes)

      if direction == :backup
        "Copia de seguridad de los archivos subidos: #{counts[:copied]} copiados a Spaces (#{size}), " \
          "#{counts[:present]} ya estaban allí, #{counts[:missing]} sin archivo en el disco, #{counts[:failed]} con errores."
      else
        "Restauración de los archivos subidos: #{counts[:restored]} descargados de Spaces (#{size}), " \
          "#{counts[:present]} ya estaban en el disco, #{counts[:not_in_bucket]} no están en Spaces, " \
          "#{counts[:failed]} con errores."
      end
    end
  end

  def initialize(bucket: BackupBucket.from_config, logger: Rails.logger)
    @bucket = bucket
    @logger = logger
  end

  # Copies to uploads/<key> every blob whose key isn't in the bucket yet. A blob without a file on disk,
  # such as an abandoned direct upload, is counted as missing.
  def backup
    stored = @bucket.keys(PREFIX)

    transfer(:backup, %i[copied present missing failed]) do |blob|
      next :present if stored.include?(blob.key)

      copy(blob)
      :copied
    rescue ActiveStorage::FileNotFoundError
      :missing
    end
  end

  # Downloads into the storage service every blob whose file is missing, when the bucket has it.
  def restore
    stored = @bucket.keys(PREFIX)

    transfer(:restore, %i[restored present not_in_bucket failed]) do |blob|
      next :present if blob.service.exist?(blob.key)
      next :not_in_bucket unless stored.include?(blob.key)

      fetch(blob)
      :restored
    end
  end

  # Lines of text about both copies, for bin/rails backup:status.
  def status
    blobs = ActiveStorage::Blob.all.to_a
    on_disk = blobs.count { |blob| blob.service.exist?(blob.key) }
    stored = @bucket.keys(PREFIX)
    not_copied = blobs.count { |blob| !stored.include?(blob.key) }

    [
      "Archivos subidos: #{blobs.size} en la base de datos, #{on_disk} en el disco (#{blobs.size - on_disk} faltan), " \
        "#{stored.size} en Spaces (#{PREFIX}), #{not_copied} sin copia en Spaces.",
      database_status
    ]
  end

  private
    # Runs the block for every blob; it returns the blob's outcome. Any error counts as :failed and is
    # logged, and the other blobs go on.
    def transfer(direction, outcomes)
      counts = outcomes.index_with(0)
      bytes = 0

      ActiveStorage::Blob.find_each do |blob|
        outcome = yield(blob)
        counts[outcome] += 1
        bytes += blob.byte_size.to_i if outcome.in?(%i[copied restored])
      rescue StandardError => error
        counts[:failed] += 1
        @logger.error("BackupUploads #{direction}: blob #{blob.id} (#{blob.key}) failed: #{error.class}: #{error.message}")
      end

      Summary.new(direction: direction, counts: counts, bytes: bytes)
    end

    # blob.open checks the file against the blob's checksum as it reads it (ActiveStorage::IntegrityError).
    def copy(blob)
      blob.open do |file|
        @bucket.upload(PREFIX + blob.key, file, content_type: blob.content_type.presence || "application/octet-stream",
          content_md5: blob.checksum)
      end
    end

    # The service checks the written file against the blob's checksum, and removes it if it doesn't match.
    def fetch(blob)
      Tempfile.create("restore-", binmode: true) do |file|
        @bucket.download(PREFIX + blob.key, file)
        file.rewind
        blob.service.upload(blob.key, file, checksum: blob.checksum)
      end
    end

    # Litestream's latest position, read from its files in the bucket: db/<level>/<first>-<last txid>.ltx,
    # where level 0009 holds the daily snapshots.
    def database_status
      files = @bucket.objects(DATABASE_PREFIX).select { |object| object.key.end_with?(".ltx") }
      return "Base de datos (Litestream, #{DATABASE_PREFIX}): ninguna réplica en Spaces todavía." if files.empty?

      txid = files.filter_map { |object| object.key[/-(\h{16})\.ltx\z/, 1] }.max
      latest = files.max_by(&:last_modified).last_modified
      snapshot = files.select { |object| object.key.include?("/0009/") }.max_by(&:last_modified)&.last_modified

      "Base de datos (Litestream, #{DATABASE_PREFIX}): #{files.size} archivos; última transacción #{txid}, " \
        "subida el #{format_time(latest)}; última instantánea: #{snapshot ? format_time(snapshot) : "ninguna todavía"}."
    end

    def format_time(time)
      time.utc.strftime("%F %T UTC")
    end
end
