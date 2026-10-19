module Csr
  module Demand
    # CSR_DemandComparison's columns married to the vocabulary the rest of the
    # app uses. The columns are read by name, never by position: the report
    # gained a Company column between two weeks, and a positional copy would
    # have shifted every column after it without an error. The 52 week columns,
    # Totals and the two $ columns are not read.
    module ColumnMap
      extend Csr::ColumnCast

      # staging column => [ attribute, type ]
      COLUMNS = {
        "CPN"                     => [ :cpn, :string ],
        "MANUFACTURER_PART"       => [ :mpn, :string ],
        "FCP_PART"                => [ :fpn, :string ],
        "CUSTOMER_NAME"           => [ :customer_name, :string ],
        "DELIVERY_ADDRESS"        => [ :ship_address, :string ],
        "COMPANY"                 => [ :company, :string ],
        "EFF_LEAD_TIME"           => [ :eff_lead_time, :integer ],
        "VARIATION_INSIDE_LT"     => [ :lt_variation, :decimal ],
        "VARIATION_INSIDE_LT_PCT" => [ :lt_variation_pct, :decimal ],
        "TOTAL_VARIATION"         => [ :total_variation, :decimal ],
        "TOTAL_VARIATION_PCT"     => [ :total_variation_pct, :decimal ],
        "STATUS"                  => [ :status, :string ]
      }.freeze

      # The part handles are stored the way Csr::PartKey stores them, so a
      # demand row resolves to its key by the same route as every other source.
      # Every attribute is present in the result, nil when the row lacks the
      # column, because insert_all! needs the same keys on every record.
      def self.cast(row)
        attrs = COLUMNS.values.to_h { |attr, _| [ attr, nil ] }.merge(super)
        attrs[:mpn] = PartKey.normalize(attrs[:mpn])
        attrs[:fpn] = PartKey.normalize(attrs[:fpn])
        attrs[:cpn] = PartKey.normalize(attrs[:cpn])
        attrs
      end
    end
  end
end
