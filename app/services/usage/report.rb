# The queries behind the usage dashboard, over csr_search_logs + users +
# user_sessions — all on the primary (PostgreSQL) database, never the
# read-only reporting connection.
#
# Raw SQL and not Active Record because most of these are aggregates across
# tables with FILTER clauses; values only ever enter through named binds,
# never interpolated.
module Usage
  class Report
    def initialize(since:)
      @since = since
    end

    attr_reader :since

    def summary
      query(<<~SQL).first || {}
        SELECT (SELECT COUNT(*) FROM users) AS registered,
               (SELECT COUNT(DISTINCT user_id) FROM csr_search_logs
                 WHERE kind = 'search' AND created_at >= :since::timestamp) AS searched,
               (SELECT COUNT(*) FROM csr_search_logs
                 WHERE kind = 'search' AND created_at >= :since::timestamp) AS searches,
               (SELECT COUNT(*) FROM csr_search_logs
                 WHERE kind = 'export' AND created_at >= :since::timestamp) AS exports,
               (SELECT COUNT(*) FROM user_sessions
                 WHERE started_at >= :since::timestamp) AS sessions,
               (SELECT MIN(created_at) FROM csr_search_logs
                 WHERE created_at >= :since::timestamp) AS first_use,
               (SELECT MAX(created_at) FROM csr_search_logs
                 WHERE created_at >= :since::timestamp) AS last_use
      SQL
    end

    def by_week
      query(<<~SQL)
        SELECT date_trunc('week', created_at)::date AS week,
               COUNT(DISTINCT user_id)                          AS users,
               COUNT(*) FILTER (WHERE kind = 'search')          AS searches,
               COUNT(*) FILTER (WHERE kind = 'export')          AS exports
        FROM csr_search_logs
        WHERE created_at >= :since::timestamp
        GROUP BY 1 ORDER BY 1
      SQL
    end

    # No pagination (nothing in the app needs it yet): the cutoff is the only limit.
    def by_user(limit: 50)
      query(<<~SQL, limit: limit)
        SELECT u.email,
               COUNT(*) FILTER (WHERE l.kind = 'search') AS searches,
               COUNT(*) FILTER (WHERE l.kind = 'export') AS exports,
               MAX(l.created_at)                         AS last_search
        FROM users u
        JOIN csr_search_logs l ON l.user_id = u.id AND l.created_at >= :since::timestamp
        GROUP BY u.email
        ORDER BY searches DESC, u.email
        LIMIT :limit
      SQL
    end

    # The "topics" analog: what people search by, not what they ask about.
    def by_search_type
      query(<<~SQL)
        SELECT search_type,
               COUNT(*)                 AS searches,
               COUNT(DISTINCT user_id)  AS users
        FROM csr_search_logs
        WHERE kind = 'search' AND created_at >= :since::timestamp
        GROUP BY 1 ORDER BY searches DESC
      SQL
    end

    # The "no answer" analog: a search that resolved to zero part keys.
    def no_results_rate
      row = query(<<~SQL).first
        SELECT COUNT(*) AS total,
               COUNT(*) FILTER (WHERE keys_found = 0) AS no_results
        FROM csr_search_logs
        WHERE kind = 'search' AND created_at >= :since::timestamp
      SQL
      total = row["total"].to_i
      return 0.0 if total.zero?

      (row["no_results"].to_i * 100.0 / total).round(1)
    end

    # Registered users who have never run a search, regardless of the cutoff
    # above — an account that searched once before the cutoff is not "never".
    def never_searched
      query(<<~SQL)
        SELECT u.email, u.sign_in_count, u.last_sign_in_at
        FROM users u
        WHERE NOT EXISTS (
          SELECT 1 FROM csr_search_logs l WHERE l.user_id = u.id AND l.kind = 'search'
        )
        ORDER BY u.sign_in_count DESC, u.email
      SQL
    end

    private

    def query(sql, extra = {})
      binds = { since: since }.merge(extra)
      ApplicationRecord.connection.select_all(
        ApplicationRecord.sanitize_sql_array([ sql, binds ]), "Usage::Report"
      ).to_a
    end
  end
end
