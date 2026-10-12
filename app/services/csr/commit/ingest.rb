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
    end
  end
end
