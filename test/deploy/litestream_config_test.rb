require "test_helper"

# config/litestream.yml, the Litestream accessory's configuration (0.5 syntax: one replica per database).
class LitestreamConfigTest < ActiveSupport::TestCase
  setup { @config = YAML.load_file(Rails.root.join("config/litestream.yml")) }

  test "it replicates the production database the app writes, in the container's storage volume" do
    production = ActiveRecord::Base.configurations.configs_for(env_name: "production", name: "primary")

    assert_equal [ "/rails/#{production.database}" ], @config["dbs"].map { |database| database["path"] }
    assert_equal "/rails/storage/production.sqlite3", @config["dbs"].first["path"]
  end

  test "the replica goes to db/ in the Spaces bucket, with every setting and key from the environment" do
    replica = @config["dbs"].first["replica"]

    assert_equal "s3", replica["type"]
    assert_equal "db", replica["path"]
    assert_equal({ "bucket" => "${SPACES_BUCKET}", "endpoint" => "${SPACES_ENDPOINT}", "region" => "${SPACES_REGION}",
                   "access-key-id" => "${SPACES_ACCESS_KEY_ID}", "secret-access-key" => "${SPACES_SECRET_ACCESS_KEY}" },
      replica.except("type", "path"))
  end

  test "any moment of the last 7 days can be restored" do
    interval, retention = @config["snapshot"].values_at("interval", "retention")

    assert_match(/\A\d+h\z/, interval)
    assert_match(/\A\d+h\z/, retention)
    # The oldest restorable moment needs the daily snapshot taken before it.
    assert_operator retention.to_i.hours, :>=, 7.days + interval.to_i.hours
  end
end
