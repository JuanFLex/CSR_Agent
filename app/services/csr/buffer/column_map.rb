module Csr
  module Buffer
    # CSR_BUFFER_READINESS's column names married to the vocabulary the rest
    # of the app uses: FCP_PART is the FPN, MANUFACTURER_PART is the MPN, and
    # DELIVERY_ADDRESS is what OSOR calls the ship-to.
    module ColumnMap
      extend Csr::ColumnCast

      # staging column => [ attribute, type ]
      COLUMNS = {
        "CPN"                       => [ :cpn,          :string ],
        "MANUFACTURER_PART"         => [ :mpn,          :string ],
        "FCP_PART"                  => [ :fpn,          :string ],
        "FCP_SITE"                  => [ :site,         :string ],
        "SUPPLIER_NAME"             => [ :supplier,     :string ],
        "CUSTOMER_ID"               => [ :customer_id,  :string ],
        "DELIVERY_ADDRESS"          => [ :ship_address, :string ],
        "SAFETY_STOCK_CONSIDER_SPQ" => [ :safety_stock, :decimal ],
        "BUCKET_DATE"               => [ :bucket_date,  :date ],
        "VS_SS"                     => [ :vs_ss,        :decimal ]
      }.freeze

      SELECT_COLUMNS = COLUMNS.keys.freeze

      # The part handles are stored the way Csr::PartKey stores them, so a
      # buffer row lands on the same key as the order lines of that part.
      def self.cast(row)
        attrs = super
        %i[cpn mpn fpn].each { |handle| attrs[handle] = PartKey.normalize(attrs[handle]) }
        attrs
      end
    end
  end
end
