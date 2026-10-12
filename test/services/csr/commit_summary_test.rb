require "test_helper"

module Csr
  class CommitSummaryTest < ActiveSupport::TestCase
    setup do
      @snapshot = Snapshot.create!(region: "Americas", source_type: "commit", status: :active, activated_at: Time.current)
      @key = csr_part_keys(:primary)
    end

    test "reports the worst week and the first week short" do
      weeks(0, -4000, -12_000, 0)

      assert_equal(-12_000, position.min_balance)
      assert_equal Date.new(2026, 10, 10), position.short_from
      assert_predicate position, :short?
    end

    test "a key whose forecast is fully committed is not short and has no date" do
      weeks(0, 0)

      assert_not_predicate position, :short?
      assert_nil position.short_from
    end

    test "takes the extremes across every row of the key" do
      weeks(0, 0, -500, customer_id: "702_ZZZFCS003")
      weeks(0, -200, 0, customer_id: "702_ZZZCAR018")

      assert_equal(-500, position.min_balance)
      assert_equal Date.new(2026, 10, 10), position.short_from
    end

    test "leaves out the keys the commit report does not carry" do
      weeks(0)

      assert_equal [ @key.id ], CommitSummary.new(PartKey.where(cpn: "CPN-100"), snapshot: @snapshot).call.keys
    end

    test "is empty until a commit snapshot exists" do
      assert_empty CommitSummary.new(PartKey.all, snapshot: nil).call
    end

    private

    def weeks(*balances, customer_id: "702_ZZZFCS003")
      balances.each_with_index do |balance, index|
        CommitLine.create!(snapshot: @snapshot, part_key: @key, cpn: @key.cpn, mpn: @key.mpn, customer_id: customer_id,
                           bucket_date: Date.new(2026, 10, 3) + index.weeks, balance: balance)
      end
    end

    def position = CommitSummary.new(PartKey.all, snapshot: @snapshot).call[@key.id]
  end
end
