require "test_helper"
require "open3"

# Runs the real bin/docker-entrypoint with stand-ins for bin/rails and bin/thrust that record their calls,
# the way the container starts it: the Dockerfile's CMD is ./bin/thrust ./bin/rails server.
class DockerEntrypointTest < ActiveSupport::TestCase
  SERVER = %w[./bin/thrust ./bin/rails server].freeze

  setup do
    @dir = Dir.mktmpdir("docker-entrypoint")
    FileUtils.mkdir_p(File.join(@dir, "bin"))
    FileUtils.cp(Rails.root.join("bin/docker-entrypoint"), File.join(@dir, "bin"))
    stub "rails", <<~SH
      echo "rails $*" >> calls.log
      if [ -n "${FAIL:-}" ] && [ "$1" == "$FAIL" ]; then exit 1; fi
    SH
    stub "thrust", <<~SH
      echo "thrust $*" >> calls.log
      exec "$@"
    SH
  end

  teardown { FileUtils.rm_rf(@dir) }

  test "starting the server prepares the database, then syncs the admin, then serves" do
    status, calls, _ = entrypoint(*SERVER)

    assert status.success?
    assert_equal [ "rails db:prepare", "rails admin:sync", "thrust ./bin/rails server", "rails server" ], calls
  end

  test "a failing admin:sync only warns: the site still starts" do
    status, calls, errors = entrypoint(*SERVER, env: { "FAIL" => "admin:sync" })

    assert status.success?
    assert_equal [ "rails db:prepare", "rails admin:sync", "thrust ./bin/rails server", "rails server" ], calls
    assert_includes errors, "admin:sync failed; starting the server anyway."
  end

  test "a failing db:prepare stops the boot" do
    status, calls, _ = entrypoint(*SERVER, env: { "FAIL" => "db:prepare" })

    assert_not status.success?
    assert_equal [ "rails db:prepare" ], calls
  end

  test "any other command runs as it is, without preparing the database or syncing the admin" do
    status, calls, _ = entrypoint("./bin/rails", "backup:status")

    assert status.success?
    assert_equal [ "rails backup:status" ], calls
  end

  private
    def stub(name, body)
      path = File.join(@dir, "bin", name)
      File.write(path, "#!/bin/bash\n#{body}")
      File.chmod(0o755, path)
    end

    def entrypoint(*command, env: {})
      _, errors, status = Open3.capture3(env, "bin/docker-entrypoint", *command, chdir: @dir)
      log = File.join(@dir, "calls.log")
      [ status, File.exist?(log) ? File.readlines(log, chomp: true) : [], errors ]
    end
end
