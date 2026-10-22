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
  end

  test "Commit shows each row's shortage, or that it is covered" do
    snapshot = active("commit")
    Csr::CommitLine.create!(snapshot:, part_key: csr_part_keys(:primary), fpn: "FCS-1", bucket_date: Date.new(2026, 10, 10), balance: -1500)
    Csr::CommitLine.create!(snapshot:, part_key: csr_part_keys(:primary), fpn: "FCS-2", bucket_date: Date.new(2026, 10, 10), balance: 0)

    get search_url(view: "commit"), params: SEARCH

    assert_select "tbody tr", text: /FCS-1.*1,500.*Oct 10/m
    assert_select "tbody tr", text: /FCS-2.*Covered/m
  end

  test "Demand Variation shows each row's movement" do
    Csr::DemandLine.create!(snapshot: active("demand"), part_key: csr_part_keys(:alternate), cpn: "CPN-100", mpn: "MPN-B",
                            customer_name: "Aguas", status: "Strong variation - Need confirmation", eff_lead_time: 21,
                            lt_variation: 3000, lt_variation_pct: 0.3, total_variation: -500, total_variation_pct: -0.05)

    get search_url(view: "demand"), params: SEARCH

    assert_select ".panel", count: 1
    assert_select "tbody tr", text: /Aguas.*21 days.*Strong variation.*\+3,000 \(\+30%\).*-500 \(-5%\)/m
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
