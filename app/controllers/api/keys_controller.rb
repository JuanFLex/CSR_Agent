module Api
  # GET /api/keys — build book Vol.2 §21, "key resolution service".
  class KeysController < BaseController
    def index
      keys = search_request.part_keys.to_a
      context = search_request.context

      render_envelope(
        count: keys.size,
        keys: keys.map { |k|
          ctx = context[k.id] || {}
          {
            key: k.key_value, cpn: k.cpn, mpn: k.mpn,
            # Arrays, not scalars: a key legitimately spans several of each, and
            # collapsing that to one value is how the Excel misreports.
            fpns: ctx[:fpn].to_a, customers: ctx[:customer].to_a,
            ship_tos: ctx[:ship_to].to_a, sites: ctx[:site].to_a
          }
        }
      )
    end
  end
end
