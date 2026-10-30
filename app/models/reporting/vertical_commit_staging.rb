module Reporting
  # CS_tempVerticalCommit, read for each CPN's end customer. Its dates do not
  # give the workbook's first week: they start a week early in some workbooks,
  # so that comes from ReportWeekStaging.
  class VerticalCommitStaging < Base
    self.table_name = "CS_tempVerticalCommit"

    # What the sheet writes when it does not know the customer.
    NO_CUSTOMER = %w[UNKNOWN].freeze

    # => { normalized CPN => end customer }. One name per CPN on the real
    # table (checked 2026-10-28: 4,476 CPNs, none with two); it agrees with
    # the FCS revenue's customer on 4,461 of 4,475.
    # ponytail: CS_CC_rptAwardGrid.End_Customer_Name covers ~3% more open-order
    # CPNs, at the cost of a second table and a rule for its CPNs with two names.
    def self.end_customers
      distinct.pluck(:CPN, :END_CUSTOMER).each_with_object({}) do |(cpn, name), names|
        cpn = Csr::PartKey.normalize(cpn)
        name = Csr::PartKey.normalize(name)
        names[cpn] = name if cpn && name && !NO_CUSTOMER.include?(name.upcase)
      end
    end

    # DATE is text, written the American way: "1/2/2027" is January 2. It
    # shares the column with the words Past and Future and the sheet's own
    # header. Ruby's own parsers read a slashed date as day/month, hence the
    # explicit format.
    def self.parse(value)
      Date.strptime(value.to_s.strip, "%m/%d/%Y")
    rescue Date::Error
      nil
    end
  end
end
