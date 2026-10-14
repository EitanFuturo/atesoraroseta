# This project's private DigitalOcean Spaces bucket (the S3 API), where the off-server backups go:
# Litestream's replica of the database under db/, and the uploaded files under uploads/ (BackupUploads).
#
#   bucket = BackupBucket.from_config
#   bucket.keys("uploads/")                     # => #<Set: {"k4x…", …}> (the keys without the prefix)
#   bucket.upload("uploads/k4x…", file, content_type: "image/webp", content_md5: blob.checksum)
#   bucket.download("uploads/k4x…", io)
#
# The settings come from the encrypted credentials (spaces.bucket, spaces.region, spaces.endpoint,
# spaces.access_key_id, spaces.secret_access_key), and the environment variables SPACES_BUCKET,
# SPACES_REGION, SPACES_ENDPOINT, SPACES_ACCESS_KEY_ID and SPACES_SECRET_ACCESS_KEY override them one by
# one. In production the first three are plain environment variables (config/deploy.yml) and the keys
# come from the credentials.
#
# It lists, reads and writes objects, and has no way to delete one.
class BackupBucket
  SETTINGS = %i[bucket region endpoint access_key_id secret_access_key].freeze

  class NotConfigured < StandardError; end

  def self.from_config(credentials: Rails.application.credentials, env: ENV, client: nil)
    settings = SETTINGS.index_with do |name|
      env["SPACES_#{name.upcase}"].presence || credential(credentials, name)
    end

    new(**settings, client: client)
  end

  def self.credential(credentials, name)
    credentials.dig(:spaces, name).presence&.to_s
  rescue StandardError # e.g. a master key that doesn't match the file
    nil
  end
  private_class_method :credential

  attr_reader :name

  def initialize(bucket:, region:, endpoint:, access_key_id:, secret_access_key:, client: nil)
    @name = bucket
    @settings = { bucket: bucket, region: region, endpoint: endpoint, access_key_id: access_key_id,
                  secret_access_key: secret_access_key }
    @client = client
  end

  def configured?
    missing_settings.empty?
  end

  # The settings that are missing, as their environment variable names: ["SPACES_BUCKET", …].
  def missing_settings
    @settings.select { |_, value| value.blank? }.keys.map { |name| "SPACES_#{name.upcase}" }
  end

  # Every object under +prefix+, in pages of up to 1,000 per request: Aws::S3::Types::Object (key, size,
  # last_modified).
  def objects(prefix)
    return enum_for(:objects, prefix) unless block_given?

    client.list_objects_v2(bucket: name, prefix: prefix).each do |page|
      page.contents.each { |object| yield object }
    end
  end

  # The keys under +prefix+, without the prefix.
  def keys(prefix)
    objects(prefix).to_set { |object| object.key.delete_prefix(prefix) }
  end

  # Stores +io+ at +key+. With content_md5 (base64 MD5, Active Storage's blob checksum) Spaces checks
  # that what arrived is intact.
  def upload(key, io, content_type:, content_md5: nil)
    client.put_object(bucket: name, key: key, body: io, content_type: content_type, content_md5: content_md5.presence)
  end

  # Writes the object at +key+ into +io+.
  def download(key, io)
    client.get_object(bucket: name, key: key, response_target: io)
  end

  private
    def client
      @client ||= begin
        unless configured?
          raise NotConfigured, "Faltan los datos del bucket de copias en Spaces: #{missing_settings.to_sentence(locale: :es)}."
        end

        require "aws-sdk-s3"
        # Path-style requests and checksums only where the API requires them work with Spaces as well as
        # with any other S3-compatible store (MinIO in the deploy rehearsal).
        Aws::S3::Client.new(region: @settings[:region], endpoint: @settings[:endpoint],
          access_key_id: @settings[:access_key_id], secret_access_key: @settings[:secret_access_key],
          force_path_style: true, request_checksum_calculation: "when_required",
          response_checksum_validation: "when_required")
      end
    end
end
