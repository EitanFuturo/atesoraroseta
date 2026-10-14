require "test_helper"
require "rake"
require_relative "../../test_helpers/fake_spaces"

# The task wiring, through the bucket the tasks configure themselves (SPACES_* and a stubbed client).
# BackupUploads has its own tests.
class BackupTasksTest < ActiveSupport::TestCase
  include FakeSpaces

  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("backup:uploads")
    [ ActiveStorage::Attachment, ActiveStorage::VariantRecord, ActiveStorage::Blob ].each(&:delete_all)
    @blob = ActiveStorage::Blob.create_and_upload!(io: file_fixture("small.png").open, filename: "small.png")
    @objects = {}
  end

  def run_task(name)
    with_fake_spaces(@objects) { capture_io { Rake::Task[name].execute } }
  end

  test "backup:uploads copies now and prints the counts" do
    output, errors = run_task("backup:uploads")

    assert_equal [ "uploads/#{@blob.key}" ], @objects.keys
    assert_match(/\ACopia de seguridad de los archivos subidos: 1 copiados a Spaces .*, 0 con errores\.\n\z/, output)
    assert_empty errors
  end

  test "backup:uploads exits with an error when a file can't be copied" do
    File.binwrite(@blob.service.path_for(@blob.key), "damaged")

    error = assert_raises(SystemExit) { run_task("backup:uploads") }

    assert_not error.success?
  end

  test "backup:restore_uploads downloads the missing files and prints the counts" do
    run_task("backup:uploads")
    File.delete(@blob.service.path_for(@blob.key))

    output, _ = run_task("backup:restore_uploads")

    assert @blob.service.exist?(@blob.key)
    assert_match(/\ARestauración de los archivos subidos: 1 descargados de Spaces/, output)
  end

  test "backup:status prints both copies" do
    output, _ = run_task("backup:status")

    assert_equal [
      "Archivos subidos: 1 en la base de datos, 1 en el disco (0 faltan), 0 en Spaces (uploads/), 1 sin copia en Spaces.",
      "Base de datos (Litestream, db/): ninguna réplica en Spaces todavía."
    ], output.lines(chomp: true)
  end
end
