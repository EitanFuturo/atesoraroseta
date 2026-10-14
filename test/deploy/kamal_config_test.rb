require "test_helper"
require "kamal"

# config/deploy.yml as Kamal itself reads it, with dummy values for any <PLACEHOLDER> still in it, so a
# change that breaks the configuration or a rule of the shared droplet fails here. Nothing connects to a
# server and no secret is read: the commands are only built.
class KamalConfigTest < ActiveSupport::TestCase
  DUMMY_VALUES = { "<SPACES_BUCKET>" => "example-bucket", "<SPACES_REGION>" => "ams3" }.freeze

  setup do
    @dir = Dir.mktmpdir("kamal-config")
    yaml = DUMMY_VALUES.reduce(Rails.root.join("config/deploy.yml").read) { |text, (placeholder, value)| text.gsub(placeholder, value) }
    File.write(File.join(@dir, "deploy.yml"), yaml)
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

  test "neither the app nor the accessory publishes a host port" do
    commands = [ app_command.run(hostname: "test"), accessory_command.run(host: @host) ].map { |command| command.join(" ") }

    commands.each do |command|
      assert_no_match(/--publish|\s-p\s/, command)
    end
  end

  test "the app gets its address, the jobs in Puma and the Spaces settings; its only secret is the master key" do
    clear = @role.env(@host).clear

    assert_equal "atesoraroseta.com", clear["APP_HOST"]
    assert_equal "true", clear["SOLID_QUEUE_IN_PUMA"].to_s
    assert_equal "60", clear["HTTP_WRITE_TIMEOUT"].to_s
    assert_equal %w[SPACES_BUCKET SPACES_ENDPOINT SPACES_REGION], clear.keys.grep(/\ASPACES_/).sort
    assert_equal [ "RAILS_MASTER_KEY" ], @role.env(@host).secret_keys
  end

  test "the Litestream accessory replicates the app's volume as the app's user" do
    accessory = @config.accessory("litestream")
    command = accessory_command.run(host: @host).join(" ")

    assert_equal "atesoraroseta-litestream", accessory.service_name
    assert_match(/\Alitestream\/litestream:0\.5\.\d+\z/, accessory.image)
    assert_equal "replicate", accessory.cmd
    assert_equal [ "/etc/litestream.yml" ], accessory.files.values.map { |file| file[:container_path] }
    assert_equal Rails.root.join("config/litestream.yml").to_s, accessory.files.keys.first
    assert_includes command, "--volume atesoraroseta_storage:/rails/storage"
    assert_includes command, '--user "1000:1000"'
    assert_equal %w[SPACES_ACCESS_KEY_ID SPACES_SECRET_ACCESS_KEY], accessory.env.secret_keys.sort
    assert_equal %w[SPACES_BUCKET SPACES_ENDPOINT SPACES_REGION], accessory.env.clear.keys.sort
  end

  test ".kamal/secrets only reads the master key and the encrypted credentials" do
    assignments = Rails.root.join(".kamal/secrets").readlines(chomp: true).grep_v(/\A\s*(#|\z)/)

    assert_equal %w[RAILS_MASTER_KEY SPACES_ACCESS_KEY_ID SPACES_SECRET_ACCESS_KEY],
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

    def accessory_command
      Kamal::Commands::Accessory.new(@config, name: "litestream")
    end
end
