require "test_helper"

module Csr
  class PartKeyTest < ActiveSupport::TestCase
    setup do
      @philo = PartKey.create!(key_value: "PLO-1|M1", cpn: "PLO-1", mpn: "M1", end_customer: "OLD NAME")
      @second_source = PartKey.create!(key_value: "PLO-1|M2", cpn: "PLO-1", mpn: "M2")
      @gone = PartKey.create!(key_value: "INV-9|M9", cpn: "INV-9", mpn: "M9", end_customer: "XYLEM")
    end

    test "every key of a CPN gets its end customer, and a CPN the sheet dropped loses it" do
      PartKey.record_end_customers!({ "PLO-1" => "PHILO" }, region: DEFAULT_REGION)

      assert_equal [ "PHILO", "PHILO", nil ], [ @philo, @second_source, @gone ].map { |key| key.reload.end_customer }
    end

    test "an empty sheet changes nothing" do
      PartKey.record_end_customers!({}, region: DEFAULT_REGION)

      assert_equal "XYLEM", @gone.reload.end_customer
    end
  end
end
