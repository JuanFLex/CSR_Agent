# The app's own tables share a SQL Server database with the tables the DBA
# maintains (CSR_OSOR_AMERICAS and friends), so everything this app owns is
# prefixed to keep the two sets unmistakable.
module Csr
  DEFAULT_REGION = "Americas".freeze

  def self.table_name_prefix
    "csr_"
  end
end
