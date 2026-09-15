require "test_helper"

module Csr
  class SnapshotTest < ActiveSupport::TestCase
    test "prune keeps the serving snapshot and the one before it, with their rows" do
      older = superseded_before(csr_snapshots(:previous))

      assert_difference -> { OsorLine.count }, -1 do
        Snapshot.prune!("osor")
      end

      assert Snapshot.exists?(csr_snapshots(:current).id)
      assert Snapshot.exists?(csr_snapshots(:previous).id)
      assert_not Snapshot.exists?(older.id)
    end

    test "prune leaves failed snapshots, other regions and other sources alone" do
      Snapshot.create!(region: "Americas", source_type: "osor", status: :failed, source_file: "rejected", row_count: 1)
      superseded_before(csr_snapshots(:previous))

      assert_no_difference -> { Snapshot.where(status: "failed").count } do
        Snapshot.prune!("osor")
      end

      assert Snapshot.exists?(csr_snapshots(:europe).id)
      assert Snapshot.exists?(csr_snapshots(:fet).id)
    end

    test "failing a snapshot deletes its rows and keeps its record" do
      snapshot = csr_snapshots(:previous)

      snapshot.fail!("rejected for the test")

      assert_predicate snapshot.reload, :failed?
      assert_equal 1, snapshot.row_count
      assert_empty snapshot.osor_lines
    end

    private

    # A superseded snapshot a day older than the given one, carrying one copied line.
    def superseded_before(snapshot)
      copy = Snapshot.create!(region: snapshot.region, source_type: snapshot.source_type, status: :superseded,
                              source_file: "older_osor", activated_at: snapshot.activated_at - 1.day, row_count: 1)
      snapshot.osor_lines.first.dup.tap { |line| line.snapshot = copy }.save!
      copy
    end
  end
end
