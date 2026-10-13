require "test_helper"
require_relative "../test_helpers/fake_spaces"

# Both directions against a fake bucket (aws-sdk-s3's stubbed client over a Hash). The blobs here are the
# test's own (the fixtures' are cleared in this test's transaction), so their files can be removed or
# damaged without touching anything other tests use.
class BackupUploadsTest < ActiveSupport::TestCase
  include FakeSpaces

  setup do
    [ ActiveStorage::Attachment, ActiveStorage::VariantRecord, ActiveStorage::Blob ].each(&:delete_all)

    @objects = {}
    @times = {}
    @bucket, @client = fake_spaces_bucket(@objects, @times)
    @log = StringIO.new
    @uploads = BackupUploads.new(bucket: @bucket, logger: Logger.new(@log))

    @png = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "small.png")
    @jpg = ActiveStorage::Blob.create_and_upload!(io: file_fixture("obra-01-d5.jpg").open, filename: "obra-01-d5.jpg")
    @variant = @png.variant(resize_to_limit: [ 100, 100 ], format: "webp").processed.image.blob
  end

  def path(blob)
    blob.service.path_for(blob.key)
  end

  def operations
    @client.api_requests.map { |request| request[:operation_name] }
  end

  test "backup copies every blob, originals and variants, byte for byte to uploads/<key>" do
    summary = @uploads.backup

    assert_equal({ copied: 3, present: 0, missing: 0, failed: 0 }, summary.counts)
    assert_equal [ @png, @jpg, @variant ].sum(&:byte_size), summary.bytes
    assert_equal [ @png, @jpg, @variant ].map { |blob| "uploads/#{blob.key}" }.sort, @objects.keys.sort
    [ @png, @jpg, @variant ].each { |blob| assert_equal blob.download, @objects["uploads/#{blob.key}"] }

    put = @client.api_requests.find { |request| request[:params][:key] == "uploads/#{@variant.key}" }
    assert_equal "image/webp", put[:params][:content_type]
    assert_equal @variant.checksum, put[:params][:content_md5], "Spaces checks what arrives against the checksum"
    assert_equal "Copia de seguridad de los archivos subidos: 3 copiados a Spaces (#{ActiveSupport::NumberHelper.number_to_human_size(summary.bytes)}), " \
      "0 ya estaban allí, 0 sin archivo en el disco, 0 con errores.", summary.message
  end

  test "a second backup copies nothing: it only lists the bucket" do
    @uploads.backup
    calls = @client.api_requests.size

    summary = @uploads.backup

    assert_equal({ copied: 0, present: 3, missing: 0, failed: 0 }, summary.counts)
    assert_equal [ :list_objects_v2 ], operations.drop(calls).uniq
  end

  test "files the bucket already has are left as they are" do
    @objects["uploads/#{@png.key}"] = "the earlier copy"

    summary = @uploads.backup

    assert_equal({ copied: 2, present: 1, missing: 0, failed: 0 }, summary.counts)
    assert_equal "the earlier copy", @objects["uploads/#{@png.key}"]
  end

  test "a blob without its file is counted as missing, and the others are still copied" do
    File.delete(path(@jpg))

    summary = @uploads.backup

    assert_equal({ copied: 2, present: 0, missing: 1, failed: 0 }, summary.counts)
    assert_not @objects.key?("uploads/#{@jpg.key}")
  end

  test "a damaged file is never copied: it is reported, and the others go on" do
    File.binwrite(path(@jpg), "not the original bytes")

    summary = @uploads.backup

    assert_equal({ copied: 2, present: 0, missing: 0, failed: 1 }, summary.counts)
    assert summary.failed?
    assert_not @objects.key?("uploads/#{@jpg.key}")
    assert_includes @log.string, "ActiveStorage::IntegrityError"
  end

  test "nothing is ever deleted: files removed in the app stay in the bucket" do
    @uploads.backup
    @jpg.purge
    File.delete(path(@png))

    @uploads.backup
    @uploads.restore

    assert @objects.key?("uploads/#{@jpg.key}")
    assert_equal %i[get_object list_objects_v2 put_object], operations.uniq.sort
  end

  test "restore brings back exactly the missing files, byte for byte, and leaves the others alone" do
    originals = [ @png, @jpg, @variant ].to_h { |blob| [ blob.key, blob.download ] }
    @uploads.backup
    File.delete(path(@png))
    File.delete(path(@variant))
    untouched = File.mtime(path(@jpg))

    summary = @uploads.restore

    assert_equal({ restored: 2, present: 1, not_in_bucket: 0, failed: 0 }, summary.counts)
    assert_equal @png.byte_size + @variant.byte_size, summary.bytes
    [ @png, @jpg, @variant ].each { |blob| assert_equal originals[blob.key], File.binread(path(blob)) }
    assert_equal untouched, File.mtime(path(@jpg))
    assert_match(/\ARestauración de los archivos subidos: 2 descargados de Spaces/, summary.message)
  end

  test "a second restore downloads nothing" do
    @uploads.backup
    File.delete(path(@png))
    @uploads.restore
    calls = @client.api_requests.size

    summary = @uploads.restore

    assert_equal({ restored: 0, present: 3, not_in_bucket: 0, failed: 0 }, summary.counts)
    assert_equal [ :list_objects_v2 ], operations.drop(calls).uniq
  end

  test "restore skips what the bucket lacks and refuses a damaged copy" do
    @uploads.backup
    @objects.delete("uploads/#{@jpg.key}")
    @objects["uploads/#{@png.key}"] = "damaged in the bucket"
    File.delete(path(@png))
    File.delete(path(@jpg))

    summary = @uploads.restore

    assert_equal({ restored: 0, present: 1, not_in_bucket: 1, failed: 1 }, summary.counts)
    assert_not File.exist?(path(@png)), "the damaged download is removed again"
    assert_not File.exist?(path(@jpg))
    assert_includes @log.string, "ActiveStorage::IntegrityError"
  end

  test "status counts the files on both sides and reads Litestream's latest position" do
    @uploads.backup
    File.delete(path(@jpg))
    @objects["uploads/#{SecureRandom.base36(28)}"] = "a file removed in the app, still kept"
    {
      "db/0000/000000000000002a-000000000000002c.ltx" => Time.utc(2026, 10, 13, 4, 12, 33),
      "db/0001/0000000000000020-0000000000000029.ltx" => Time.utc(2026, 10, 13, 4, 12, 0),
      "db/0009/0000000000000001-0000000000000025.ltx" => Time.utc(2026, 10, 13, 1, 0, 1)
    }.each do |key, time|
      @objects[key] = "ltx"
      @times[key] = time
    end

    assert_equal [
      "Archivos subidos: 3 en la base de datos, 2 en el disco (1 faltan), 4 en Spaces (uploads/), 0 sin copia en Spaces.",
      "Base de datos (Litestream, db/): 3 archivos; última transacción 000000000000002c, subida el 2026-10-13 04:12:33 UTC; " \
        "última instantánea: 2026-10-13 01:00:01 UTC."
    ], @uploads.status
  end

  test "status says so when Litestream hasn't replicated anything yet" do
    assert_equal "Base de datos (Litestream, db/): ninguna réplica en Spaces todavía.", @uploads.status.last
    assert_match(/3 sin copia en Spaces\.\z/, @uploads.status.first)
  end
end
