class AddEndCustomerToPartKeys < ActiveRecord::Migration[8.0]
  def change
    # The customer the part is built for (Philo, Xylem…), not Flex's sold-to.
    # The workbook gives exactly one per CPN, so it sits on the key rather
    # than on every fact.
    add_column :csr_part_keys, :end_customer, :string, limit: 200
  end
end
