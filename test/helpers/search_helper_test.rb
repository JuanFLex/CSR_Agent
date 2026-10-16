require "test_helper"

class SearchHelperTest < ActionView::TestCase
  test "short_date shows the year only outside the current year" do
    this_year = Date.current.change(month: 3, day: 7)

    assert_equal "Mar 07", short_date(this_year)
    assert_equal "Mar 07, #{this_year.year - 1}", short_date(this_year.prev_year)
    assert_equal "—", short_date(nil)
  end

  test "an unconfirmed line shows how long ago the order was created" do
    line = Csr::OsorLine.new(order_date: 3.days.ago, pdd: 1.week.from_now)

    assert_includes risk_pill(line), "Unconfirmed +3d"
    assert_includes risk_pill(Csr::OsorLine.new), "Unconfirmed<"
  end

  test "a late line says so with an icon as well as a colour" do
    line = Csr::OsorLine.new(miss: true, pdd: Time.zone.local(2026, 9, 1), cdd: Time.zone.local(2026, 9, 8))

    assert_match(/class="pill late"><svg.*Late \+7d/, risk_pill(line))
  end

  test "the pager shows the ends and the current page's neighbours" do
    assert_equal [ 1, 2, 3, nil, 8 ], pager_pages(2, 8)
    assert_equal [ 1, nil, 4, 5, 6, nil, 8 ], pager_pages(5, 8)
    assert_equal [ 1 ], pager_pages(1, 1)
  end
end
