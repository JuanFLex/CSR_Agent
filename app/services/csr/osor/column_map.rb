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
      # Baan writes the Unix epoch where it means "no date". Anything at or
      # before this is not a real date and must not be treated as one — a
      # 1970 CDD would otherwise read as wildly early rather than as missing.
      EPOCH_SENTINEL = Time.utc(1970, 1, 2).freeze

      # Strings Baan uses to mean "empty".
      NULL_TOKENS = [ "NULL", "null", "-", "" ].freeze

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

        "lastupdate"          => [ :source_last_update,  :datetime ]
      }.freeze

      # Staging columns deliberately left out: they are pivot helpers or values
      # this app recomputes itself (SQPID, numitems, sourg, maucprice,
      # SOPPVPrice, SOPPVTotal, LoadSPQMistmatch, porefa, itemspq, itemmoq,
      # pivotd, SOS). Add one here the day a screen actually needs it.

      module_function

      # Turn one staging row into attributes for Csr::OsorLine.
      def cast(row)
        attrs = {}

        row.each do |raw_column, raw_value|
          mapping = COLUMNS[raw_column.to_s.downcase]
          next unless mapping

          attribute, type = mapping
          attrs[attribute] = coerce(raw_value, type)
        end

        attrs
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
end
