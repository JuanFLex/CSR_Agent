module Csr
  module Osor
    # The one place where CSR_OSOR_AMERICAS's column names are married to the
    # build book's vocabulary.
    #
    # This matters more than it looks. Every document, formula and conversation
    # about this system says PDD, CDD and FPN; the staging table says
    # PLANDELDATE, COMMDELDATE and ITEM. If that translation is scattered across
    # the codebase, nobody can read Vol.2 and follow the app. So it lives here,
    # once.
    module ColumnMap
      # The casting itself — epoch sentinels, "NULL" strings, separators in
      # numbers — is the same for every source and lives in Csr::ColumnCast.
      extend Csr::ColumnCast

      # staging column (downcased) => [ attribute, type ]
      COLUMNS = {
        # identity — note the three renames the build book cares about
        "cpn_edi"             => [ :cpn,                 :string ],
        "mpn"                 => [ :mpn,                 :string ],
        "item"                => [ :fpn,                 :string ],
        "description"         => [ :description,         :string ],
        "manufacturers"       => [ :manufacturer,        :string ],

        # customer / order
        "orderdate"           => [ :order_date,          :datetime ],
        "soldtobp"            => [ :sold_to_bp,          :string ],
        "bp_name"             => [ :bp_name,             :string ],
        "shipaddress"         => [ :ship_address,        :string ],
        "cpo"                 => [ :cpo,                 :string ],
        "cpo_pos"             => [ :cpo_pos,             :string ],
        "so"                  => [ :so,                  :string ],
        "pos"                 => [ :so_pos,              :string ],
        "seq"                 => [ :seq,                 :string ],

        # purchase order
        "po"                  => [ :po,                  :string ],
        "popos"               => [ :po_pos,              :string ],
        "poqty"               => [ :po_qty,              :decimal ],
        "poprice"             => [ :po_price,            :decimal ],
        "po_confirmdate"      => [ :po_confirm_date,     :datetime ],
        "po_changedate"       => [ :po_change_date,      :datetime ],
        "poactivity"          => [ :po_activity,         :string ],

        # status
        "condition"           => [ :error_condition,     :string ],
        "so_status"           => [ :so_status,           :string ],
        "sotype"              => [ :so_type,             :string ],
        "load"                => [ :load_code,           :string ],
        "loadlinestatus"      => [ :load_line_status,    :string ],
        "loadgeneral"         => [ :load_general,        :string ],
        "blocked"             => [ :blocked,             :string ],
        "block_codes"         => [ :block_codes,         :string ],
        "invstatus"           => [ :inv_status,          :string ],

        # quantities
        "baan_ordered"        => [ :baan_ordered,        :decimal ],
        "spq"                 => [ :spq,                 :decimal ],
        "spq_ordered"         => [ :spq_ordered,         :decimal ],
        "moq"                 => [ :moq,                 :decimal ],
        "stock"               => [ :stock,               :decimal ],
        "block"               => [ :block_qty,           :decimal ],
        "free"                => [ :free_qty,            :decimal ],
        "price"               => [ :price,               :decimal ],
        "amount"              => [ :amount,              :decimal ],
        "ppv"                 => [ :ppv,                 :decimal ],

        # warehouses
        "sowhs"               => [ :so_whs,              :string ],
        "whs"                 => [ :whs,                 :string ],
        "inv_whs"             => [ :inv_whs,             :string ],

        # the dates the risk model turns on
        "plandeldate"         => [ :pdd,                 :datetime ],
        "commdeldate"         => [ :cdd,                 :datetime ],
        "promdeldate"         => [ :promdd,              :datetime ],
        "previouscommdeldate" => [ :previous_cdd,        :datetime ],
        "custreqdate"         => [ :cust_req_date,       :datetime ],
        "custrecdate"         => [ :cust_rec_date,       :datetime ],
        "daysprevioscdd"      => [ :days_previous_cdd,   :integer ],
        "datescondition"      => [ :dates_condition,     :string ],

        "kinaxis_unconfirm"   => [ :kinaxis_unconfirmed, :string ],
        "kinaxis_confirmed"   => [ :kinaxis_confirmed,   :string ],
        "refa"                => [ :ref_a,               :string ],
        "refb"                => [ :ref_b,               :string ],

        "lastupdate"          => [ :source_last_update,  :datetime ],

        # Shown by tOSOR, so the portal can show them too.
        "sourg"               => [ :project,             :string ],
        "sos"                 => [ :so_urgent,           :string ],
        "porefa"              => [ :po_ref_a,            :string ],
        "loadspqmistmatch"    => [ :load_spq_mismatch,   :string ],
        "maucprice"           => [ :mauc_price,          :decimal ],
        "soppvprice"          => [ :so_ppv_price,        :decimal ],
        "soppvtotal"          => [ :so_ppv_total,        :decimal ]
      }.freeze

      # Staging columns deliberately left out: SQPID, numitems, itemspq,
      # itemmoq and pivotd. They are pivot helpers, and tOSOR does not show
      # them to the Excel's user either.
    end
  end
end
