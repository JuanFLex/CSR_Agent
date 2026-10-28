module Csr
  module Commit
    # Copies the "Balance" row of every part in CSR_CustomerCommitment into a
    # new snapshot.
    #
    # A commit row carries CPN and MPN, so it resolves to a CPN|MPN key the
    # same way an order line does, and a part with a forecast but no open
    # order still gets its key.
    class Ingest < WeeklyIngest
      def initialize(staging: Reporting::CommitStaging, **options)
        super
      end

      private

      def source_type = "commit"
      def column_map = ColumnMap
      def line_model = CommitLine
      def value_attribute = :balance

      # The end customer comes from the same workbook's vertical sheet, which
      # carries the same CPNs, so it is refreshed with every commit load. Like
      # the history, a failure here must not fail a snapshot already serving.
      def record_history(snapshot)
        super
        PartKey.record_end_customers!(@calendar.end_customers, region: @region)
      rescue StandardError => e
        Rails.logger.error("[csr.commit] recording end customers failed: #{e.message}")
      end
    end
  end
end
