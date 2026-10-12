module Csr
  module Buffer
    # Copies the "Balance vs SS (Buffer Stock)" row of every part in
    # CS_tempTrendBufferReadinessProjection into a new snapshot.
    #
    # A buffer row carries CPN and MPN, so it resolves to a CPN|MPN key the
    # same way an order line does, and a part with a buffer but no open order
    # still gets its key.
    class Ingest < WeeklyIngest
      def initialize(staging: Reporting::BufferStaging, **options)
        super
      end

      private

      def source_type = "buffer"
      def column_map = ColumnMap
      def line_model = BufferLine
      def value_attribute = :vs_ss
    end
  end
end
