module Csr
  module Buffer
    # CS_tempTrendBufferReadinessProjection's column names married to the
    # vocabulary the rest of the app uses: FCP_PART is the FPN,
    # MANUFACTURER_PART is the MPN, and DELIVERY_ADDRESS is what OSOR calls
    # the ship-to.
    module ColumnMap
      extend Csr::ColumnCast
      extend Csr::WeeklyColumnMap

      # staging column => [ attribute, type ]
      COLUMNS = {
        "CPN"                       => [ :cpn,          :string ],
        "MANUFACTURER_PART"         => [ :mpn,          :string ],
        "FCP_PART"                  => [ :fpn,          :string ],
        "FCP_SITE"                  => [ :site,         :string ],
        "SUPPLIER_NAME"             => [ :supplier,     :string ],
        "CUSTOMER_ID"               => [ :customer_id,  :string ],
        "DELIVERY_ADDRESS"          => [ :ship_address, :string ],
        "SAFETY_STOCK_CONSIDER_SPQ"  => [ :safety_stock,      :decimal ],
        "ALLOCATED_CUSTOMER_ON_HAND" => [ :allocated_on_hand, :decimal ]
      }.freeze

      # The sheet has 51 dated weeks and the table 50 numbered columns, so the
      # last week landed in FUTURE: it is the 51st week, not a bucket for
      # everything beyond. PAST is left out, as the workbook leaves it out.
      WEEK_COLUMNS = [ *(21..70).map { |n| "F#{n}" }, "FUTURE" ].freeze
    end
  end
end
