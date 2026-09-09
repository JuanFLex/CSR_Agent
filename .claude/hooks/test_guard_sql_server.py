#!/usr/bin/env python3
"""Contract for guard_sql_server.py.

The cases live in a file rather than on a command line because the guard reads
whole command lines: a shell script listing "DROP TABLE" as test data looks
exactly like one running it. Run with `python3 .claude/hooks/test_guard_sql_server.py`.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from guard_sql_server import verdict  # noqa: E402

BLOCK = [
    ("tsql running DROP", 'tsql -S prod -Q "DROP TABLE CSR_OSOR_AMERICAS"'),
    ("DELETE piped to tsql", 'echo "DELETE FROM CSR_OSOR_AMERICAS" | tsql -S prod'),
    ("sqlcmd running TRUNCATE", 'sqlcmd -S prod -Q "TRUNCATE TABLE CSR_OSOR_AMERICAS"'),
    ("bcp bulk load", 'freebcp CSR_OSOR_AMERICAS in data.csv -S prod'),
    ("schema task at reporting", "bin/rails db:migrate:reporting"),
    ("drop of reporting", "bin/rails db:drop:reporting"),
    ("--database reporting", "bin/rails db:schema:load --database reporting"),
    ("write through Reporting", 'bin/rails runner "Reporting::OsorStaging.first.update!(CPO: 1)"'),
    ("raw execute on Reporting", 'bin/rails runner "Reporting::Base.connection.execute(%q{DROP TABLE x})"'),
]

ALLOW = [
    # The app's own database is not this hook's business.
    ("migrate the app database", "bin/rails db:migrate"),
    ("seed the app database", "bin/rails db:seed"),
    ("reset the app database", "bin/rails db:reset"),
    ("create a user", 'bin/rails runner "User.create!(email: \'a@b.c\')"'),
    ("run the ingest", 'bin/rails runner "Csr::Osor::Ingest.new.call"'),
    ("open the console", "bin/rails console"),
    ("run the test suite", "bin/rails test"),
    # Reads against SQL Server are the entire point of having the connection.
    ("tsql SELECT", 'tsql -S prod -Q "SELECT TOP 5 * FROM CSR_OSOR_AMERICAS"'),
    ("count the staging rows", 'bin/rails runner "puts Reporting::OsorStaging.count"'),
    # Reading the staging table and then writing an app table is two different
    # things; the guard must not let the first poison the second.
    (
        "read staging, then write the app",
        'bin/rails runner "puts Reporting::OsorStaging.count\nCsr::Snapshot.create!(source_type: %q{osor})"',
    ),
    # Ordinary file work, including text that merely names a schema task.
    ("read a file", "cat app/models/reporting/base.rb"),
    ("grep the code", "grep -rn insert_all app/"),
    ("heredoc naming a schema task", "python3 - <<PY\n# a comment about db:migrate and Reporting::Base\nPY"),
    ("git status", "git status"),
]


def main():
    failures = []

    for label, command in BLOCK:
        if verdict(command) is None:
            failures.append(f"  should have blocked: {label}")

    for label, command in ALLOW:
        result = verdict(command)
        if result is not None:
            failures.append(f"  should have allowed: {label}  (matched {result[1]!r})")

    total = len(BLOCK) + len(ALLOW)
    if failures:
        print(f"FAIL — {len(failures)} of {total} cases wrong:")
        print("\n".join(failures))
        return 1

    print(f"OK — {len(BLOCK)} blocked, {len(ALLOW)} allowed, {total} cases")
    return 0


if __name__ == "__main__":
    sys.exit(main())
