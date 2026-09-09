module Reporting
  # Tables this app reads but never owns: they are maintained by the DBA's own
  # ETL and truncate+load process.
  #
  # The read-only promise is enforced rather than documented, because "we only
  # read from your table" is the kind of assurance that quietly stops being true
  # the first time someone adds a convenient update.
  class Base < ActiveRecord::Base
    self.abstract_class = true

    # A separate connection from the app's own tables, so the boundary is
    # structural rather than a convention. It can carry a db_datareader login of
    # its own, and `database_tasks: false` in database.yml keeps Rails from ever
    # aiming a schema task at it.
    connects_to database: { reading: :reporting, writing: :reporting }

    def readonly?
      true
    end
  end
end
