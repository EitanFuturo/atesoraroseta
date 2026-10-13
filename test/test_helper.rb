ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

# Files uploaded during a run (fixture blobs, attachments, variants) go to a directory of the run's own
# under tmp/storage, deleted when the run ends. Parallel workers share it; concurrent runs don't.
ActiveStorage::Blob.service.root = Rails.root.join("tmp/storage/run-#{Process.pid}").to_s
Minitest.after_run { FileUtils.rm_rf(ActiveStorage::Blob.service.root) }

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Something Active Storage can attach: a file from test/fixtures/files.
    #
    #   artwork.image.attach(fixture_attachable("obra-01-d5.jpg"))
    #   Artwork.create!(title: "…", image: fixture_attachable("small.png"))
    def fixture_attachable(filename)
      { io: file_fixture(filename).open, filename: filename }
    end
  end
end
