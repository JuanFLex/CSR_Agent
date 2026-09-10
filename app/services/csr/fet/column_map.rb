module Csr
  module Fet
    # CSR_FET's column names married to the vocabulary the rest of the app uses.
    #
    # Two renames carry the weight: ITEM is the FPN, and MFG_PARTNO is the MPN.
    # The column CSR_FET calls MPN is empty in practice, which is why it is not
    # here — reading it would silently drop every escalation.
    module ColumnMap
      extend Csr::ColumnCast

      # staging column => [ attribute, type ]
      COLUMNS = {
        "COMP_ID"                 => [ :comp_id,             :string ],
        "FACILITY"                => [ :facility,            :string ],
        "REGION_CODE"             => [ :region_code,         :string ],

        "ESCALATION_ID"           => [ :escalation_id,       :integer ],
        "ESCALATION_NUMBER"       => [ :escalation_number,   :string ],
        "ESCALATION_TYPE"         => [ :escalation_type,     :string ],
        "ESCALATION_STATUS"       => [ :escalation_status,   :string ],
        "ESCALATION_GROUP"        => [ :escalation_group,    :string ],

        "ITEM"                    => [ :fpn,                 :string ],
        "ITEM_DESC"               => [ :description,         :string ],
        "MFG_PARTNO"              => [ :mpn,                 :string ],
        "GLOBAL_MFG_NAME"         => [ :manufacturer,        :string ],
        "GLOBAL_SUPP_NAME"        => [ :supplier,            :string ],
        "GLOBAL_CUST_NAME"        => [ :customer,            :string ],

        "DATE_OPENED"             => [ :date_opened,         :datetime ],
        "UPDATED_DATE"            => [ :updated_date,        :datetime ],
        "CLOSED_DATE"             => [ :closed_date,         :datetime ],
        "IMPACT_DATE"             => [ :impact_date,         :datetime ],
        "DAYS_OPEN"               => [ :days_open,           :integer ],

        "SHORTAGE_QTY"            => [ :shortage_qty,        :decimal ],
        "SITE_REVENUE_IMPACT"     => [ :site_revenue_impact, :string ],
        "LINE_DOWN"               => [ :line_down,           :string ],
        "ITEM_ON_ALLOCATION"      => [ :item_on_allocation,  :string ],
        "REASON_CODE_DESC"        => [ :reason_code,         :string ],

        "CURRENT_OWNER_NAME"      => [ :owner_name,          :string ],
        "CURRENT_OWNER_EMAIL"     => [ :owner_email,         :string ],
        "CURRENT_OWNER_ROLE"      => [ :owner_role,          :string ],
        "AGE_CURRENT_OWNER"       => [ :age_current_owner,   :integer ],
        "LAST_ACTION_COMMENTS"    => [ :last_action_comments, :string ]
      }.freeze

      # CSR_FET has 95 columns; these are the ones a screen or a join uses.
      # Reading only them keeps the copy small. Add one the day it is needed.
      SELECT_COLUMNS = COLUMNS.keys.freeze

      # The part handles are stored the way Csr::PartKey stores them, so an
      # escalation can be matched to a key by equality rather than by guesswork.
      def self.cast(row)
        attrs = super
        attrs[:mpn] = PartKey.normalize(attrs[:mpn])
        attrs[:fpn] = PartKey.normalize(attrs[:fpn])
        attrs
      end
    end
  end
end
