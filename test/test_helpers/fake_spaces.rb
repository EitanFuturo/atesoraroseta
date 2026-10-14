require "aws-sdk-s3"

# A stand-in for the Spaces backups bucket: aws-sdk-s3's own stubbed client (stub_responses), whose objects
# live in a Hash (key => bytes), so a test sees exactly what was stored, and nothing reaches the network.
# Listings come in pages of PAGE_SIZE objects, the way the real API pages every 1,000.
module FakeSpaces
  PAGE_SIZE = 3
  SETTINGS = { bucket: "atesoraroseta-backups", region: "ams3", endpoint: "https://ams3.digitaloceanspaces.com",
               access_key_id: "test-access-key-id", secret_access_key: "test-secret-access-key" }.freeze

  # A BackupBucket on a stubbed client over +objects+ (with optional +times+: key => last_modified).
  # Returns [bucket, client]; client.api_requests records every call.
  def fake_spaces_bucket(objects = {}, times = {})
    client = Aws::S3::Client.new(stub_responses: fake_spaces_stubs(objects, times), region: SETTINGS[:region])
    [ BackupBucket.new(**SETTINGS, client: client), client ]
  end

  # Runs the block with the SPACES_* variables set and every new S3 client stubbed over +objects+, for code
  # that builds its own BackupBucket (the job, the rake tasks). Real credentials are never used.
  def with_fake_spaces(objects = {})
    names = SETTINGS.keys.map { |name| "SPACES_#{name.upcase}" }
    previous = names.index_with { |name| ENV[name] }
    SETTINGS.each { |name, value| ENV["SPACES_#{name.upcase}"] = value }
    Aws.config[:s3] = { stub_responses: fake_spaces_stubs(objects, {}) }
    yield
  ensure
    Aws.config.delete(:s3)
    previous.each { |name, value| ENV[name] = value }
  end

  private
    def fake_spaces_stubs(objects, times)
      {
        list_objects_v2: ->(context) do
          keys = objects.keys.select { |key| key.start_with?(context.params[:prefix].to_s) }.sort
          start = context.params[:continuation_token].to_i
          truncated = start + PAGE_SIZE < keys.size
          contents = keys[start, PAGE_SIZE].to_a.map do |key|
            { key: key, size: objects[key].bytesize, last_modified: times.fetch(key, Time.utc(2026, 1, 1)) }
          end
          { contents: contents, is_truncated: truncated, next_continuation_token: (truncated ? (start + PAGE_SIZE).to_s : nil) }
        end,
        put_object: ->(context) do
          objects[context.params[:key]] = context.params[:body].read.b
          {}
        end,
        get_object: ->(context) do
          objects.key?(context.params[:key]) ? { body: objects[context.params[:key]] } : "NoSuchKey"
        end
      }
    end
end
