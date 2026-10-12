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
end
