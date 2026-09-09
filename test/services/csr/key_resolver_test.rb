require "test_helper"

module Csr
  class KeyResolverTest < ActiveSupport::TestCase
    setup do
      @snapshot = csr_snapshots(:current)
    end

    test "cpn resolves both mpns without duplicating keys for repeated lines" do
      assert_resolves %i[primary alternate], search_type: "CPN", value: " \tCPN-100\n "
    end

    test "mpn resolves the matching key in the requested region" do
      assert_resolves %i[primary], search_type: "mpn", value: " MPN-A "
    end

    test "fpn resolves through snapshot lines and ignores unkeyed lines" do
      assert_resolves %i[primary alternate], search_type: "fpn", value: " FCS-CPN-100 "
    end

    test "so resolves all keys on the order" do
      assert_resolves %i[primary alternate], search_type: "so", value: "SO100"
    end

    test "cpo line splits at the first hyphen and accepts a whole cpo" do
      assert_resolves %i[primary], search_type: "cpo_line", value: " PO100 - 20-1 "
      assert_resolves %i[alternate], search_type: "cpo_line", value: "PO100-30"
      assert_resolves %i[primary alternate], search_type: "cpo_line", value: "PO100"
    end

    test "uses the supplied snapshot and region rather than unrelated lines" do
      assert_resolves [], search_type: "so", value: "SOOLD"
      assert_resolves %i[primary], search_type: "so", value: "SOOLD", snapshot: csr_snapshots(:previous)
      assert_resolves %i[europe], search_type: "so", value: "SO100",
                      snapshot: csr_snapshots(:europe), region: "Europe"
      assert_resolves %i[europe], search_type: "cpn", value: "CPN-100",
                      snapshot: csr_snapshots(:europe), region: "Europe"
    end

    test "returns an empty relation for blank invalid or unavailable searches" do
      assert_resolves [], search_type: "cpn", value: " "
      assert_resolves [], search_type: "invalid", value: "CPN-100"
      assert_resolves [], search_type: "cpn", value: "UNKNOWN"

      Snapshot.active.update_all(status: :superseded)
      assert_resolves [], search_type: "cpn", value: "CPN-100", snapshot: nil
    end

    test "requires an explicit snapshot and never selects a fallback" do
      assert_raises(ArgumentError) { KeyResolver.new(search_type: "cpn", value: "CPN-100") }

      Snapshot.stub(:current, ->(*) { flunk "The caller must select the snapshot" }) do
        assert_resolves [], search_type: "cpn", value: "CPN-100", snapshot: nil
      end
    end

    private

    def assert_resolves(keys, search_type:, value:, snapshot: @snapshot, region: "Americas")
      result = KeyResolver.new(search_type: search_type, value: value, snapshot: snapshot, region: region).call

      assert_kind_of ActiveRecord::Relation, result
      assert_equal keys.map { |key| csr_part_keys(key).id }.sort, result.ids.sort
    end
  end
end
