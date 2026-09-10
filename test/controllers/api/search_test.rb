require "test_helper"

module Api
  class SearchTest < ActionDispatch::IntegrationTest
    setup do
      @snapshot = csr_snapshots(:current)
    end

    test "status keeps execution numbers separate from snapshot metadata" do
      get api_status_url, params: { search_type: "cpn", value: " CPN-100 " }

      assert_envelope
      assert_equal(
        {
          "combos_found" => 2, "open_lines" => 4, "misses" => 2,
          "etd_min" => Time.utc(2026, 9, 9, 8).as_json,
          "etd_max" => Time.utc(2026, 9, 12, 8).as_json,
          "open_qty" => BigDecimal("19.5").as_json,
          "unconfirmed" => 1
        },
        response.parsed_body.fetch("execution")
      )
    end

    test "keys include context without a separate count query" do
      assert_queries_count(3) do
        get api_keys_url, params: { search_type: "cpn", value: "CPN-100" }
      end

      assert_envelope
      body = response.parsed_body
      assert_equal 2, body.fetch("count")
      assert_equal %w[CPN-100|MPN-A CPN-100|MPN-B], body.fetch("keys").map { |key| key.fetch("key") }.sort
      primary = body.fetch("keys").find { |key| key.fetch("mpn") == "MPN-A" }
      assert_equal %w[FCS-CPN-100 FCS-MPN-A], primary.fetch("fpns")
      assert_equal [ "Customer A", "Customer B" ], primary.fetch("customers")
      assert_equal %w[SHIP-A SHIP-B], primary.fetch("ship_tos")
      assert_equal %w[GDL MTY], primary.fetch("sites")
    end

    test "orders include the shared envelope and all matching lines below the limit" do
      get api_orders_url, params: { search_type: "cpn", value: "CPN-100" }

      assert_envelope
      body = response.parsed_body
      assert_equal 4, body.fetch("count")
      assert_equal false, body.fetch("truncated")
      assert_equal 4, body.fetch("orders").size
      assert_equal 2, body.fetch("orders").count { |line| line.fetch("miss") }
      assert_equal %w[MPN-A MPN-B], body.fetch("orders").map { |line| line.fetch("mpn") }.uniq.sort
    end

    test "orders report truncation only above 500 lines" do
      Csr::OsorLine.in_snapshot(@snapshot).delete_all
      key = csr_part_keys(:primary)
      previous_count = 0

      [ 499, 500, 501 ].each do |count|
        rows = (previous_count...count).map do |index|
          {
            snapshot_id: @snapshot.id, part_key_id: key.id, cpn: key.cpn, mpn: key.mpn,
            so: "SO-LIMIT", so_pos: (index + 1).to_s, cdd: Time.utc(2026, 9, 10) + index.seconds
          }
        end
        Csr::OsorLine.insert_all!(rows)
        previous_count = count

        get api_orders_url, params: { search_type: "cpn", value: "CPN-100" }

        assert_envelope
        body = response.parsed_body
        expected_count = [ count, 500 ].min
        assert_equal expected_count, body.fetch("count")
        assert_equal expected_count, body.fetch("orders").size
        assert_equal count > 500, body.fetch("truncated"), "#{count} matching lines"
        assert_equal expected_count.to_s, body.fetch("orders").last.fetch("so_pos")
      end

      get root_url, params: { search_type: "cpn", value: "CPN-100" }

      assert_response :success
      assert_select "table.lines tbody tr", count: 500
      assert_select "h2 .count", text: "(500 of 501)"
    end

    test "all endpoints return empty results and metadata without an active snapshot" do
      Csr::Snapshot.active.update_all(status: :superseded)

      {
        api_status_url => {
          "execution" => {
            "combos_found" => 0, "open_lines" => 0, "misses" => 0,
            "etd_min" => nil, "etd_max" => nil, "open_qty" => 0, "unconfirmed" => 0
          }
        },
        api_keys_url => { "count" => 0, "keys" => [] },
        api_orders_url => { "count" => 0, "truncated" => false, "orders" => [] }
      }.each do |url, payload|
        get url, params: { search_type: "cpn", value: "CPN-100" }

        assert_envelope(snapshot: nil)
        assert_equal payload, response.parsed_body.except("query", "meta")
      end

      get root_url, params: { search_type: "cpn", value: "CPN-100" }

      assert_response :success
      assert_select ".warn", text: /No OSOR snapshot is active yet/
    end

    private

    def assert_envelope(snapshot: @snapshot)
      assert_response :success
      body = response.parsed_body
      assert_equal({ "search_type" => "cpn", "value" => "CPN-100" }, body.fetch("query"))
      assert_equal(
        {
          "snapshot_id" => snapshot&.id, "source_file" => snapshot&.source_file,
          "fresh_as_of" => snapshot&.fresh_as_of&.as_json
        },
        body.fetch("meta")
      )
    end
  end
end
