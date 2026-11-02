require "test_helper"

# The left menu's pages: one per source, each reached with the search it was
# opened from.
class SourcePagesTest < ActionDispatch::IntegrationTest
  SEARCH = { search_type: "cpn", value: "CPN-100" }.freeze

  setup { sign_in users(:regular) }

  test "the menu carries the search to every page and marks the one shown" do
    get search_url(view: "commit"), params: SEARCH

    assert_response :success
    assert_select ".sidenav a", count: SearchController::VIEWS.size
    assert_select ".sidenav a[aria-current=page]", text: "Commit"
    assert_select ".sidenav a[href=?]", search_path(view: "buffer", **SEARCH, region: "Americas"), text: "Buffer Readiness"
    assert_select ".sidenav a", text: /Open Orders\s*4/
  end

  test "an unknown page is not a route" do
    get "/search/kinaxis", params: SEARCH

    assert_response :not_found
  end

  test "Open Orders shows only the orders, and its pager stays on the page" do
    with_page_size(2) { get search_url(view: "orders"), params: SEARCH }

    assert_select "table.lines tbody tr", count: 2
    assert_select ".cards", count: 0
    assert_select ".pager a[aria-label='Next page'][href^=?]", "/search/orders?"
  end

  test "Escalations says when there are none" do
    Csr::Escalation.delete_all
    get search_url(view: "escalations"), params: SEARCH

    assert_select "table.escalations", count: 0
    assert_select ".hint", text: /No open escalations/
  end

  test "Buffer Readiness lists each row of each key with its allocated stock and coverage" do
    snapshot = active("buffer")
    buffer_week(snapshot, csr_part_keys(:primary), site: "702", safety_stock: 4000, allocated_on_hand: 40_000, vs_ss: 0.5, week: 0)
    buffer_week(snapshot, csr_part_keys(:primary), site: "702", safety_stock: 4000, allocated_on_hand: 40_000, vs_ss: 2, week: 1)
    buffer_week(snapshot, csr_part_keys(:primary), site: "703", safety_stock: 0, allocated_on_hand: 0, vs_ss: 0, week: 0)

    get search_url(view: "buffer"), params: SEARCH

    assert_select ".panel", count: 1, text: /CPN-100\|.*MPN-A.*Below target · 0.5×/m
    assert_select "tbody tr", text: /702.*4,000.*40,000.*10×.*0.5×.*Oct 10/m
    assert_select "tbody tr", text: /703.*No target/m
    assert_select ".chart svg[aria-label^=?] polyline", "Projected balance against safety stock", count: 2
  end

  test "Commit shows each row's shortage, or that it is covered" do
    snapshot = active("commit")
    Csr::CommitLine.create!(snapshot:, part_key: csr_part_keys(:primary), fpn: "FCS-1", bucket_date: Date.new(2026, 10, 10), balance: -1500)
    Csr::CommitLine.create!(snapshot:, part_key: csr_part_keys(:primary), fpn: "FCS-2", bucket_date: Date.new(2026, 10, 10), balance: 0)

    get search_url(view: "commit"), params: SEARCH

    assert_select "tbody tr", text: /FCS-1.*1,500.*Oct 10/m
    assert_select "tbody tr", text: /FCS-2.*Covered/m
    assert_select ".chart svg path.bar.short", count: 1
  end

  test "Demand Variation shows each row's movement" do
    Csr::DemandLine.create!(snapshot: active("demand"), part_key: csr_part_keys(:alternate), cpn: "CPN-100", mpn: "MPN-B",
                            customer_name: "Aguas", status: "Strong variation - Need confirmation", eff_lead_time: 21,
                            lt_variation: 3000, lt_variation_pct: 0.3, total_variation: -500, total_variation_pct: -0.05)

    get search_url(view: "demand"), params: SEARCH

    assert_select ".panel", count: 1
    assert_select "tbody tr", text: /Aguas.*21 days.*Strong variation.*\+3,000 \(\+30%\).*-500 \(-5%\)/m
  end

  test "the dashboard leads with each source's worst key" do
    buffer_week(active("buffer"), csr_part_keys(:primary), safety_stock: 4000, vs_ss: 0.5, week: 0)
    Csr::CommitLine.create!(snapshot: active("commit"), part_key: csr_part_keys(:alternate), bucket_date: Date.new(2026, 10, 10), balance: -1500)

    get root_url, params: SEARCH

    assert_select ".cards.supply .card.bad", text: /Lowest buffer\s*0.5×\s*below safety stock · 1 key/
    assert_select ".cards.supply .card.bad", text: /Commit\s*Short 1,500/
    assert_select ".cards.supply .card", text: /Demand inside LT\s*—\s*not in the Demand Comparison report/
  end

  test "the dashboard pairs orders with the worst key's existing Buffer chart without combining keys" do
    snapshot = active("buffer")
    csr_part_keys(:alternate).update!(end_customer: "PHILO")
    [ 2, 0.5 ].each_with_index do |ratio, week|
      buffer_week(snapshot, csr_part_keys(:primary), safety_stock: 4000, vs_ss: ratio, week: week)
    end
    [ -1, 0 ].each_with_index do |ratio, week|
      buffer_week(snapshot, csr_part_keys(:alternate), safety_stock: 8000, vs_ss: ratio, week: week)
    end
    buffer_week(snapshot, csr_part_keys(:other), safety_stock: 10_000, vs_ss: -99, week: 0)
    buffer_week(snapshot, csr_part_keys(:europe), safety_stock: 10_000, vs_ss: -99, week: 0)
    old = Csr::Snapshot.create!(region: "Americas", source_type: "buffer", status: :superseded)
    buffer_week(old, csr_part_keys(:primary), safety_stock: 4000, vs_ss: -99, week: 0)

    get root_url, params: SEARCH

    assert_response :success
    assert_select ".cards.supply + .dashboard-overview table.lines tbody tr", count: 4
    assert_select ".dashboard-overview + .split table.keys tbody tr", count: 2
    assert_select ".dashboard-buffer .selected-key", text: /CPN-100\|.*MPN-B.*PHILO.*Below target · -1×/m
    assert_select ".dashboard-buffer .table-note", text: /Lowest-buffer key.*other keys are not combined/
    assert_select ".dashboard-buffer a[href=?]", search_path(view: "buffer", **SEARCH, region: "Americas"), text: "Buffer details"
    assert_select ".dashboard-buffer svg", count: 1
    assert_select ".dashboard-buffer svg[aria-label$=?] title", "CPN-100|MPN-B", text: /Oct 3, 2026\s+Projected balance: -8,000\s+Safety stock: 8,000/
    chart = css_select(".dashboard-buffer svg").first.to_html
    assert_select "h3", text: "Allocated on hand, week over week", count: 0

    get search_url(view: "buffer"), params: SEARCH

    assert_equal chart, css_select("svg[aria-label$='CPN-100|MPN-B']").first.to_html
    assert_select "h3", text: "Allocated on hand, week over week", count: 2
  end

  test "the dashboard also shows a single covered key and keeps the detail link's search" do
    snapshot = active("buffer")
    buffer_week(snapshot, csr_part_keys(:primary), safety_stock: 4000, vs_ss: 2, week: 0)
    buffer_week(snapshot, csr_part_keys(:primary), safety_stock: 4000, vs_ss: 1, week: 1)
    search = { search_type: "mpn", value: "MPN-A", region: "Americas" }

    get search_url(view: "dashboard"), params: search

    assert_response :success
    assert_select ".dashboard-buffer .selected-key", text: /CPN-100\|.*MPN-A.*Covered · 1×/m
    assert_select ".dashboard-buffer svg", count: 1
    assert_select ".dashboard-buffer .table-note", count: 0
    assert_select ".dashboard-buffer a[href=?]", search_path(view: "buffer", **search), text: "Buffer details"
  end

  test "the dashboard distinguishes a source not loaded from parts absent from Buffer" do
    get root_url, params: SEARCH

    assert_select ".dashboard-buffer .hint", text: "Buffer Readiness has not been loaded yet."
    assert_select ".dashboard-buffer svg", count: 0
    assert_select ".dashboard-overview table.lines tbody tr", count: 4

    buffer_week(active("buffer"), csr_part_keys(:other), safety_stock: 4000, vs_ss: 1, week: 0)
    get root_url, params: SEARCH

    assert_select ".dashboard-buffer .hint", text: "The Buffer Readiness report carries none of these parts."
    assert_select ".dashboard-buffer svg", count: 0
  end

  test "the dashboard does not draw a fabricated projection when no key has a target" do
    buffer_week(active("buffer"), csr_part_keys(:primary), safety_stock: 0, vs_ss: 0, week: 0)

    get root_url, params: SEARCH

    assert_select ".dashboard-buffer .hint", text: "No projection with a safety stock target is available for these parts."
    assert_select ".dashboard-buffer svg", count: 0
    assert_select ".dashboard-buffer .selected-key", count: 0
  end

  test "keys without a target cannot displace a covered key on the dashboard" do
    snapshot = active("buffer")
    buffer_week(snapshot, csr_part_keys(:primary), safety_stock: 0, vs_ss: -99, week: 0)
    buffer_week(snapshot, csr_part_keys(:alternate), safety_stock: 4000, vs_ss: 2, week: 0)

    get root_url, params: SEARCH

    assert_select ".dashboard-buffer .selected-key", text: /CPN-100\|.*MPN-B.*Covered · 2×/m
    assert_select ".dashboard-buffer svg", count: 1
  end

  test "tied Buffer keys are selected in key order rather than query order" do
    snapshot = active("buffer")
    %i[alternate primary].each do |key|
      buffer_week(snapshot, csr_part_keys(key), safety_stock: 4000, vs_ss: 0.5, week: 0)
    end

    get root_url, params: SEARCH

    assert_select ".dashboard-buffer .selected-key", text: /CPN-100\|.*MPN-A.*Below target · 0.5×/m
  end

  test "the dashboard projection does not appear on blank or unmatched searches or on Open Orders" do
    buffer_week(active("buffer"), csr_part_keys(:primary), safety_stock: 4000, vs_ss: 0.5, week: 0)
    get root_url
    assert_select ".dashboard-overview", count: 0

    get root_url, params: { search_type: "cpn", value: "NOT-FOUND" }
    assert_select ".dashboard-overview", count: 0

    get search_url(view: "orders"), params: SEARCH
    assert_select ".dashboard-overview", count: 0
    assert_select "table.lines tbody tr", count: 4
  end

  test "the keys table and the source pages name the end customer, and show a dash where it is unknown" do
    csr_part_keys(:primary).update!(end_customer: "PHILO")
    Csr::CommitLine.create!(snapshot: active("commit"), part_key: csr_part_keys(:primary), bucket_date: Date.new(2026, 10, 10), balance: 0)

    get root_url, params: SEARCH

    assert_select "table.keys tbody tr", text: /CPN-100\|.*MPN-A\s*PHILO/m
    assert_select "table.keys tbody tr", text: /MPN-B\s*—/m

    get search_url(view: "commit"), params: SEARCH

    assert_select ".panel-head h2 .end-customer", text: "PHILO"
  end

  private

  def active(source)
    Csr::Snapshot.create!(region: "Americas", source_type: source, status: :active, activated_at: Time.current)
  end

  def buffer_week(snapshot, key, week:, **values)
    Csr::BufferLine.create!(snapshot:, part_key: key, bucket_date: Date.new(2026, 10, 3) + 7 * week, **values)
  end

  def with_page_size(count)
    original = Csr::SearchRequest::LINES_PER_PAGE
    Csr::SearchRequest.send(:remove_const, :LINES_PER_PAGE)
    Csr::SearchRequest.const_set(:LINES_PER_PAGE, count)
    yield
  ensure
    Csr::SearchRequest.send(:remove_const, :LINES_PER_PAGE)
    Csr::SearchRequest.const_set(:LINES_PER_PAGE, original)
  end
end
