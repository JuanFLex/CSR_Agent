module Csr
  # Turning staging values into Ruby ones. Shared by every source, because they
  # all come out of the same Baan exports and lie in the same ways: "NULL" as a
  # string, the Unix epoch meaning "no date", numbers carrying separators.
  #
  # A source's own ColumnMap extends this and supplies COLUMNS.
  module ColumnCast
    extend self

    # Baan writes the Unix epoch where it means "no date". Anything at or
    # before this is not a real date and must not be treated as one — a 1970
    # CDD would otherwise read as wildly early rather than as missing.
    EPOCH_SENTINEL = Time.utc(1970, 1, 2).freeze

    # Strings Baan uses to mean "empty".
    NULL_TOKENS = [ "NULL", "null", "-", "" ].freeze

    # Turn one staging row into attributes, using the map's own COLUMNS.
    # Staging spells its columns however it likes; the lookup is case-blind.
    def cast(row)
      lookup = (@column_lookup ||= self::COLUMNS.transform_keys { |name| name.to_s.downcase })

      row.each_with_object({}) do |(raw_column, raw_value), attrs|
        mapping = lookup[raw_column.to_s.downcase]
        next unless mapping

        attribute, type = mapping
        attrs[attribute] = coerce(raw_value, type)
      end
    end

    def coerce(value, type)
      return nil if value.nil?
      return nil if value.is_a?(String) && NULL_TOKENS.include?(value.strip)

      case type
      when :string   then value.to_s.strip.presence
      when :decimal  then to_decimal(value)
      when :integer  then to_decimal(value)&.to_i
      when :datetime then to_time(value)
      end
    end

    def to_decimal(value)
      return value if value.is_a?(BigDecimal)
      return BigDecimal(value.to_s) if value.is_a?(Numeric)

      text = value.to_s.strip.delete(",")
      return nil if text.empty?

      BigDecimal(text)
    rescue ArgumentError
      nil
    end

    def to_time(value)
      time =
        case value
        when Time, DateTime then value
        when Date           then value.to_time
        else
          parsed = value.to_s.strip
          return nil if parsed.empty?

          begin
            Time.zone.parse(parsed)
          rescue ArgumentError
            nil
          end
        end

      return nil if time.nil?
      return nil if time <= EPOCH_SENTINEL

      time
    end
  end
end
