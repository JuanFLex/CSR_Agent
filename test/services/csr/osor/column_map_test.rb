require "test_helper"

module Csr
  module Osor
    class ColumnMapTest < ActiveSupport::TestCase
      test "coerces null tokens and trims strings" do
        [ nil, *ColumnMap::NULL_TOKENS, " NULL ", " null ", " - ", "  " ].each do |value|
          [ :string, :decimal, :integer, :datetime ].each do |type|
            assert_nil ColumnMap.coerce(value, type), "#{value.inspect} as #{type}"
          end
        end

        assert_equal "CPN-100", ColumnMap.coerce(" CPN-100 ", :string)
      end

      test "coerces decimals with thousands separators and integer quantities" do
        assert_equal BigDecimal("1234.5678"), ColumnMap.coerce(" 1,234.5678 ", :decimal)
        assert_equal BigDecimal("-1234.5"), ColumnMap.coerce("-1,234.5", :decimal)
        assert_equal BigDecimal("12.5"), ColumnMap.coerce(12.5, :decimal)
        assert_equal 1234, ColumnMap.coerce("1,234.9", :integer)
        assert_nil ColumnMap.coerce("invalid", :decimal)
      end

      test "rejects epoch sentinel times and preserves real driver timestamps" do
        [ Time.utc(1969, 12, 31), Time.utc(1970, 1, 1), ColumnMap::EPOCH_SENTINEL ].each do |time|
          assert_nil ColumnMap.coerce(time, :datetime)
        end

        time = Time.utc(2026, 9, 7, 15, 38, 31)
        assert_equal time, ColumnMap.coerce(time, :datetime)
      end

      test "parses strings in the Rails time zone and respects explicit offsets" do
        Time.use_zone("Asia/Tokyo") do
          time = ColumnMap.to_time(" 2026-09-07 15:38:31 ")

          assert_equal Time.zone.local(2026, 9, 7, 15, 38, 31), time
          assert_kind_of ActiveSupport::TimeWithZone, time
          assert_equal Time.utc(2026, 9, 7, 12, 38, 31), ColumnMap.to_time("2026-09-07T15:38:31+03:00")
        end
      end

      test "rejects string epochs and invalid dates without hiding unexpected parser errors" do
        Time.use_zone("America/Mexico_City") do
          [ "1970-01-01 00:00:00", ColumnMap::EPOCH_SENTINEL.iso8601,
            "", " ", "invalid", "2026-13-07 15:38:31" ].each do |value|
            assert_nil ColumnMap.to_time(value), value.inspect
          end

          Time.zone.stub(:parse, ->(*) { raise TypeError, "unexpected parser error" }) do
            assert_raises(TypeError) { ColumnMap.to_time("2026-09-07 15:38:31") }
          end
        end
      end
    end
  end
end
