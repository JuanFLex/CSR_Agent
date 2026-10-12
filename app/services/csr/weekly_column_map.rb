module Csr
  # For a ColumnMap whose sheet arrives one column per week. On top of the
  # mapped attributes, `cast` returns `:weeks`, the values of WEEK_COLUMNS in
  # order, and stores the part handles the way Csr::PartKey does, so a row
  # lands on the same key as the order lines of that part.
  #
  # Extend it after Csr::ColumnCast.
  module WeeklyColumnMap
    def cast(row)
      attrs = super
      %i[cpn mpn fpn].each { |handle| attrs[handle] = PartKey.normalize(attrs[handle]) }

      values = row.transform_keys { |name| name.to_s.downcase }
      attrs.merge(weeks: self::WEEK_COLUMNS.map { |column| coerce(values[column.downcase], :decimal) })
    end

    def select_columns
      self::COLUMNS.keys + self::WEEK_COLUMNS
    end
  end
end
