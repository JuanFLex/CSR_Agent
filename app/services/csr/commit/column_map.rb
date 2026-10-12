module Csr
  module Commit
    # CSR_CustomerCommitment's columns, which have no names of their own (see
    # Reporting::CommitStaging), married to the vocabulary the rest of the app
    # uses. The comment beside each is its header in the sheet: Part is the
    # FPN, and Delivery Address is what OSOR calls the ship-to.
    module ColumnMap
      extend Csr::ColumnCast
      extend Csr::WeeklyColumnMap

      # staging column => [ attribute, type ]
      COLUMNS = {
        "NoName4" => [ :cpn,          :string ], # CPN
        "NoName6" => [ :mpn,          :string ], # MPN
        "NoName5" => [ :fpn,          :string ], # Part
        "NoName2" => [ :customer_id,  :string ], # Customer
        "NoName3" => [ :ship_address, :string ]  # Delivery Address
      }.freeze

      # The 52 dated weeks. ETD before them is the sheet's Past, and F70 and
      # NoName15 after them are its Future and Sum: all three are 0 on every
      # Balance row, so they are left out.
      WEEK_COLUMNS = (18..69).map { |n| "F#{n}" }.freeze
    end
  end
end
