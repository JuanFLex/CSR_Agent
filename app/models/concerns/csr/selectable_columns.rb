module Csr
  # A table whose reader picks the columns. The model declares COLUMNS (in
  # display order) and DEFAULT_COLUMNS; this turns whatever arrives from a URL
  # or a cookie into a safe list.
  module SelectableColumns
    # Whatever was asked for, kept to the columns that exist and to the order
    # the model declares, so a hand-typed URL cannot reorder or inject.
    def columns_for(requested)
      chosen = self::COLUMNS.keys & Array(requested).map { |name| name.to_s.to_sym }
      chosen.presence || self::DEFAULT_COLUMNS
    end

    def numeric_column?(column)
      type_for_attribute(column).type.in?(%i[integer decimal])
    end
  end
end
