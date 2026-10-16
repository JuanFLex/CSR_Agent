require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:regular) }

  test "displays the requested region" do
    get root_url, params: { region: "Europe" }

    assert_response :success
    assert_select "h1 .region", text: "Europe"
  end

  test "renders the summary keys context lines and snapshot freshness" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_response :success
    assert_select "table.keys tbody tr", count: 2
    assert_select "table.lines tbody tr", count: 4
    assert_select "table.keys td.multi", text: /FCS-CPN-100.*FCS-MPN-A/m
    assert_select ".freshness[title=?]", "CSR_OSOR_AMERICAS · snapshot ##{csr_snapshots(:current).id}", text: /OSOR.*Sep 07, 15:38/m
    assert_select ".cards .card:last-child.minor .value", text: "2"
  end

  test "marks every source without an active snapshot as not loaded" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".sources .source.live", count: 2
    assert_select ".sources .source.not-loaded", count: 3
    assert_select ".sources .source.not-loaded.impact", text: /Demand.*not loaded.*forecast coverage unavailable/m
    assert_select ".sources", text: /Retry/, count: 0
  end

  test "tells how long ago the open orders were refreshed" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".query .refreshed", text: /Last refreshed .* ago · Sep 07, \d{4} 15:38/
  end

  test "summarizes the search and offers it as an email draft" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select ".narrative li", minimum: 1
    assert_select ".query .actions a.primary[href^='mailto:?'][href*='subject=CSR'][href*='body=CPN']"
  end

  test "lists the open escalations raised against the searched MPNs" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.escalations tbody tr", count: 2
    assert_select "table.escalations tbody tr.miss td", text: /20250716610058.2/
    assert_select ".narrative li", text: /2 open escalations on these FPNs, 1 with the line down/
  end

  test "shows the default escalation columns and swaps them for the chosen ones" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.escalations thead th", text: "FET #"
    assert_select "table.escalations thead th", text: "Global customer", count: 0

    get root_url, params: { search_type: "cpn", value: "CPN-100", escalation_columns: %w[mpn customer nonsense] }

    assert_select "table.escalations thead th", text: "Global customer"
    assert_select "table.escalations thead th", text: "FET #", count: 0
    assert_equal "mpn,customer", cookies[:escalation_columns], "the choice is remembered per browser"
  end

  test "shows the default order columns and swaps them for the chosen ones" do
    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.lines thead th", text: "Need (PDD)"
    assert_select "table.lines thead th", text: "Project", count: 0

    get root_url, params: { search_type: "cpn", value: "CPN-100",
                            line_columns: %w[cpo_ref project amount_qty_price] }

    assert_select "table.lines thead th", text: "Project"
    assert_select "table.lines thead th", text: "Amount = Qty x Price"
    assert_select "table.lines thead th", text: "Need (PDD)", count: 0
  end

  test "falls back to the default columns when the request names none that exist" do
    get root_url, params: { search_type: "cpn", value: "CPN-100", escalation_columns: %w[drop_table] }

    assert_select "table.escalations thead th", text: "FET #"
  end

  test "exports every open line of the search as CSV" do
    get search_url(format: :csv), params: { search_type: "cpn", value: "CPN-100" }

    assert_response :success
    assert_equal "text/csv", response.media_type
    rows = CSV.parse(response.body)
    assert_equal Csr::OsorLine::DEFAULT_COLUMNS.map { |c| Csr::OsorLine::COLUMNS[c] }, rows.first
    assert_equal 4, rows.size - 1
  end

  test "the CSV export carries the columns the table was showing" do
    get search_url(format: :csv), params: { search_type: "cpn", value: "CPN-100", line_columns: %w[mpn miss] }

    assert_equal [ "MPN", "Late" ], CSV.parse(response.body).first
  end

  test "shows where each key's buffer stands" do
    snapshot = Csr::Snapshot.create!(region: "Americas", source_type: "buffer", status: :active,
                                     source_file: "CS_tempTrendBufferReadinessProjection", activated_at: Time.current)
    [ 2, 0.5, 1 ].each_with_index do |ratio, week|
      Csr::BufferLine.create!(snapshot: snapshot, part_key: csr_part_keys(:primary), safety_stock: 8000,
                              bucket_date: Date.new(2026, 9, 26) + week.weeks, vs_ss: ratio)
    end

    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.keys tbody tr", text: /MPN-A.*Below target · 0.5×.*at target from Sep 26/m, count: 1
    assert_select "table.keys .pill", count: 1, message: "a key the buffer report does not carry shows no state"
    assert_select ".narrative li", text: /Buffer: 1 of 1 key with a safety stock drops below it \(lowest 0.5×\)/
    assert_select ".sources .source.live[title^=?]", "CS_tempTrendBufferReadinessProjection", text: /Buffer/
  end

  test "shows where each key's commit stands" do
    snapshot = Csr::Snapshot.create!(region: "Americas", source_type: "commit", status: :active,
                                     source_file: "CSR_CustomerCommitment", activated_at: Time.current)
    { primary: [ 0, -4000, -43_645, 0 ], alternate: [ 0, 0 ] }.each do |key, balances|
      balances.each_with_index do |balance, week|
        Csr::CommitLine.create!(snapshot: snapshot, part_key: csr_part_keys(key),
                                bucket_date: Date.new(2026, 10, 3) + week.weeks, balance: balance)
      end
    end

    get root_url, params: { search_type: "cpn", value: "CPN-100" }

    assert_select "table.keys tbody tr", text: /MPN-A.*Short · 43,645.*from Oct 10/m, count: 1
    assert_select "table.keys tbody tr", text: /MPN-B.*Covered/m, count: 1
    assert_select ".narrative li", text: /Commit: 1 of 2 keys runs short of the forecast \(up to 43,645 pcs, from Oct 10\)/
    assert_select ".sources .source.live[title^=?]", "CSR_CustomerCommitment", text: /Commit/
  end

  test "keeps the admin pages and logout in the account menu" do
    get root_url

    assert_select "details.account .menu", text: /#{users(:regular).email}/
    assert_select "details.account .menu button.logout", text: "Log out"
    assert_select "details.account a", text: "Users", count: 0

    sign_in users(:admin)
    get root_url

    assert_select "details.account .menu a[href=?]", admin_users_path, text: "Users"
    assert_select "details.account .menu a[href=?]", admin_usage_path, text: "Usage"
  end
end
