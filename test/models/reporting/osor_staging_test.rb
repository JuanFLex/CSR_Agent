require "test_helper"

module Reporting
  # The staging table belongs to the DBA. These tests pin the promise that this
  # app only ever reads it, so that a future convenience write fails here rather
  # than in production against a table nobody expected us to touch.
  class OsorStagingTest < ActiveSupport::TestCase
    setup do
      connection = OsorStaging.connection
      connection.drop_table(OsorStaging.table_name, if_exists: true)
      connection.create_table(OsorStaging.table_name, id: false) do |t|
        t.string :CPO
        t.string :CPN_EDI
        t.string :MPN
        t.datetime :lastupdate
      end
      connection.insert_fixture(
        { "CPO" => "335971550", "CPN_EDI" => "CBR1-170-0117-01",
          "MPN" => "0451020.MRL", "lastupdate" => "2026-09-07 15:38:31" },
        OsorStaging.table_name
      )
    end

    teardown do
      OsorStaging.connection.drop_table(OsorStaging.table_name, if_exists: true)
    end

    test "reads the staging table" do
      assert_equal 1, OsorStaging.count
      assert_equal "335971550", OsorStaging.first.CPO
    end

    test "refuses to update a row" do
      assert_raises(ActiveRecord::ReadOnlyRecord) do
        OsorStaging.first.update!(CPO: "tampered")
      end
    end

    test "refuses to destroy a row" do
      assert_raises(ActiveRecord::ReadOnlyRecord) { OsorStaging.first.destroy }
    end

    test "read-only comes from the base class, so it covers every future model" do
      assert_operator OsorStaging, :<, Base
      assert OsorStaging.new.readonly?
      assert_equal Base.instance_method(:readonly?), OsorStaging.instance_method(:readonly?),
                   "readonly? must stay on Reporting::Base rather than be repeated per model"
    end

    test "uses a connection separate from the app's own tables" do
      refute_equal Csr::PartKey.connection_db_config.name,
                   OsorStaging.connection_db_config.name,
                   "staging must not share the app's connection: the boundary is what lets it carry a read-only login"
    end

    test "the reporting connection is excluded from schema tasks" do
      configurations = ActiveRecord::Base.configurations

      # Rails hides a database_tasks:false connection from the listing that the
      # db:* tasks walk. Being absent here is precisely what keeps a migration
      # from ever reaching the DBA's server.
      visible = configurations.configs_for(env_name: Rails.env).map(&:name)
      refute_includes visible, "reporting",
                      "reporting must stay out of the schema-task listing"

      config = configurations.configs_for(env_name: Rails.env, name: "reporting",
                                          include_hidden: true)
      assert config, "reporting must still be configured, just hidden from tasks"
      refute config.database_tasks?
    end

    test "reads the freshness watermark" do
      assert_equal Time.utc(2026, 9, 7, 15, 38, 31).to_i, OsorStaging.watermark.utc.to_i
    end
  end
end
