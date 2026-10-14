require "test_helper"
require "kamal"

# config/deploy.yml as Kamal itself reads it, with dummy values for any <PLACEHOLDER> still in it, so a
# change that breaks the configuration or a rule of the shared droplet fails here. Nothing connects to a
# server and no secret is read: the commands are only built.
class KamalConfigTest < ActiveSupport::TestCase
  setup do
    @dir = Dir.mktmpdir("kamal-config")
    File.write(File.join(@dir, "deploy.yml"), Rails.root.join("config/deploy.yml").read)
    @config = Kamal::Configuration.create_from(config_file: Pathname(File.join(@dir, "deploy.yml")), version: "test")
    @host = @config.primary_host
    @role = @config.role(:web)
  end

  teardown { FileUtils.rm_rf(@dir) }

  test "the app has its own names, image and volume" do
    assert_equal "atesoraroseta", @config.service
    assert @config.registry.local?, "the image goes through Kamal's local registry, not an external one"
    assert_equal "localhost:5555/atesoraroseta", @config.repository
    assert_equal 1, @config.all_hosts.size
    assert_equal [ "--volume", "atesoraroseta_storage:/rails/storage" ], @config.volume_args
  end

  test "kamal-proxy serves both names over HTTPS with per-app options only" do
    options = @role.proxy.deploy_options

    assert_equal [ "atesoraroseta.com", "www.atesoraroseta.com" ], options[:host]
    assert options[:tls]
    assert_equal "/up", options[:"health-check-path"]
    assert_operator options[:"target-timeout"].to_i, :>=, 60
    assert_operator options[:"max-request-body"], :>=, ImageAttachments::MAX_BYTES + 4.megabytes
    assert_nil @config.proxy_run(@host), "proxy/run would reconfigure the proxy every project on the server shares"
  end

  test "the app publishes no host port" do
    assert_no_match(/--publish|\s-p\s/, app_command.run(hostname: "test").join(" "))
  end

  test "the app's memory is capped, so it can't starve the other projects on the 1 GB droplet" do
    assert_includes app_command.run(hostname: "test").join(" "), '--memory "600m"'
  end

  test "the app gets its address and the jobs in Puma; its only secret is the master key" do
    clear = @role.env(@host).clear

    assert_equal "atesoraroseta.com", clear["APP_HOST"]
    assert_equal "true", clear["SOLID_QUEUE_IN_PUMA"].to_s
    assert_equal "60", clear["HTTP_WRITE_TIMEOUT"].to_s
    assert_equal [ "RAILS_MASTER_KEY" ], @role.env(@host).secret_keys
  end

  test "off-server backups are off: no Litestream accessory and no Spaces settings" do
    assert_empty @config.accessories
    assert_empty @role.env(@host).clear.keys.grep(/\ASPACES_/)
  end

  test ".kamal/secrets only reads the master key and the encrypted credentials" do
    assignments = Rails.root.join(".kamal/secrets").readlines(chomp: true).grep_v(/\A\s*(#|\z)/)

    assert_equal %w[RAILS_MASTER_KEY],
      assignments.map { |line| line.split("=", 2).first }
    assignments.each do |line|
      assert_match(/\A[A-Z_]+=\$\((cat config\/master\.key|bin\/rails credentials:fetch [a-z_.]+)\)\z/, line)
    end
    assert_no_match(/admin/i, assignments.join("\n"), "the app reads the admin login from the credentials itself")
  end

  private
    def app_command
      Kamal::Commands::App.new(@config, role: @role, host: @host)
    end
end
