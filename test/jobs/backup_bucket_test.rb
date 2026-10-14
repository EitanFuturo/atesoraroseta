require "test_helper"
require_relative "../test_helpers/fake_spaces"

class BackupBucketTest < ActiveSupport::TestCase
  include FakeSpaces

  CREDENTIALS = {
    spaces: { bucket: "bucket-from-credentials", region: "fra1", endpoint: "https://fra1.digitaloceanspaces.com",
              access_key_id: "key-from-credentials", secret_access_key: "secret-from-credentials" }
  }.freeze

  # The real client the bucket would use (it connects to nothing until a request is made).
  def client_config(bucket)
    bucket.send(:client).config
  end

  test "the settings come from the encrypted credentials" do
    bucket = BackupBucket.from_config(credentials: CREDENTIALS, env: {})
    config = client_config(bucket)

    assert bucket.configured?
    assert_equal "bucket-from-credentials", bucket.name
    assert_equal "fra1", config.region
    assert_equal "https://fra1.digitaloceanspaces.com", config.endpoint.to_s
    assert_equal "key-from-credentials", config.credentials.access_key_id
  end

  test "SPACES_* variables override the credentials one by one, and blank ones are ignored" do
    env = { "SPACES_BUCKET" => "bucket-from-env", "SPACES_ENDPOINT" => "http://minio:9000", "SPACES_REGION" => "" }
    bucket = BackupBucket.from_config(credentials: CREDENTIALS, env: env)
    config = client_config(bucket)

    assert_equal "bucket-from-env", bucket.name
    assert_equal "http://minio:9000", config.endpoint.to_s
    assert_equal "fra1", config.region
    assert_equal "secret-from-credentials", config.credentials.secret_access_key
  end

  test "the client uses path-style requests and checksums only where required, which Spaces and MinIO accept" do
    config = client_config(BackupBucket.from_config(credentials: CREDENTIALS, env: {}))

    assert config.force_path_style
    assert_equal "when_required", config.request_checksum_calculation
    assert_equal "when_required", config.response_checksum_validation
  end

  test "without settings it names what is missing and sends no request" do
    bucket = BackupBucket.from_config(credentials: {}, env: { "SPACES_BUCKET" => "solo-el-bucket" })

    assert_not bucket.configured?
    assert_equal %w[SPACES_REGION SPACES_ENDPOINT SPACES_ACCESS_KEY_ID SPACES_SECRET_ACCESS_KEY], bucket.missing_settings
    error = assert_raises(BackupBucket::NotConfigured) { bucket.keys("uploads/") }
    assert_equal "Faltan los datos del bucket de copias en Spaces: SPACES_REGION, SPACES_ENDPOINT, " \
      "SPACES_ACCESS_KEY_ID y SPACES_SECRET_ACCESS_KEY.", error.message
  end

  test "credentials that can't be read count as missing" do
    unreadable = Object.new
    def unreadable.dig(*) = raise(ActiveSupport::MessageEncryptor::InvalidMessage)

    bucket = BackupBucket.from_config(credentials: unreadable, env: {})

    assert_equal 5, bucket.missing_settings.size
  end

  test "keys lists every object under a prefix, page after page, without the prefix" do
    objects = (1..7).to_h { |n| [ "uploads/key#{n}", "x" ] }.merge("db/0000/a.ltx" => "y", "uploads-old/z" => "z")
    bucket, client = fake_spaces_bucket(objects)

    assert_equal (1..7).map { |n| "key#{n}" }.to_set, bucket.keys("uploads/")
    assert_equal 3, client.api_requests.count { |request| request[:operation_name] == :list_objects_v2 }
  end

  test "it can list, read and write objects, and nothing else" do
    assert_empty BackupBucket.public_instance_methods(false).grep(/delete|remove|purge|destroy/)
  end
end
