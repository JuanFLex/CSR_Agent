#!/usr/bin/env python3
"""Refuse Bash commands that could write to SQL Server.

SQL Server belongs to the DBA and this app only ever reads from it. Everything
else is fair game: the app's own tables (users, snapshots, part keys, order
lines) live on the `primary` connection, and ordinary Rails development there —
migrating, seeding, writing, the console — is not this hook's business.

So the test is about *invocation*, not about text. A command is examined only
when it actually runs a SQL client or a Rails/rake task; a heredoc that merely
mentions a schema task inside a comment is not running one.

Three layers guard SQL Server, and this is only the outermost:
  1. this hook, which stops a command before it leaves the machine
  2. `database_tasks: false` on the reporting connection, so Rails never aims
     schema tasks at it
  3. Reporting::Base#readonly? and, ideally, a db_datareader login — the only
     one of the three that a pattern cannot slip past
"""
import json
import re
import sys

# Clients that talk to SQL Server directly, bypassing Rails entirely.
SQL_CLIENT = re.compile(r"\b(tsql|sqlcmd|isql|bsqldb|freebcp|bcp)\b")

# Bulk copy carries no SQL keywords at all, so direction is what gives it away:
# "in" loads a file into a table, "out" and "queryout" only read.
BULK_LOAD = re.compile(r"\b(freebcp|bcp)\b[^|;&]*\s+in\s+", re.I)

# An actual Rails/rake invocation, not the word "rails" inside a string.
RAILS_INVOKE = re.compile(r"(?:^|[;&|]\s*|\s)(?:bundle\s+exec\s+)?(?:bin/)?(?:rails|rake)\s")

SQL_WRITE = re.compile(
    r"\b(insert\s+into|update\s+\S+\s+set|delete\s+from|merge\s+into"
    r"|drop\s+(table|database|index|view|schema|login|user)"
    r"|truncate\s+table|alter\s+(table|database|index|schema)"
    r"|create\s+(table|database|index|view|schema|login|user)"
    r"|bulk\s+insert|grant\s+|revoke\s+|sp_\w+|xp_\w+)\b",
    re.I,
)

# Rails tasks aimed at the reporting connection specifically. A bare schema task
# is fine: database_tasks: false already keeps it away from SQL Server.
REPORTING_TASK = re.compile(
    r"\bdb:[\w:]*:reporting\b|--database[=\s]+reporting\b|\bdbconsole\b[^|;&]*\breporting\b",
    re.I,
)

# Writes attempted through the read-only models. Bounded to a single statement:
# spanning newlines and semicolons would let a harmless read of Reporting::
# poison an ordinary app write later in the same script.
REPORTING_WRITE = re.compile(
    r"Reporting::\w+[^\n;]{0,160}?(\.save!?\b|\.update!?\b|\.update_all\b|\.destroy!?\b"
    r"|\.delete!?\b|\.delete_all\b|\binsert_all!?\b|\bupsert_all\b|\.create!?\s*\("
    r"|connection\.execute|exec_update|exec_delete|exec_insert)"
)


def verdict(command):
    if not command:
        return None

    if SQL_CLIENT.search(command):
        found = SQL_WRITE.search(command)
        if found:
            return "SQL that changes data or schema", found.group(0).strip()

        found = BULK_LOAD.search(command)
        if found:
            return "a bulk load into a table", found.group(0).strip()

    if RAILS_INVOKE.search(command):
        found = REPORTING_TASK.search(command)
        if found:
            return "a Rails task aimed at the reporting connection", found.group(0).strip()

        found = REPORTING_WRITE.search(command)
        if found:
            return "a write through a read-only Reporting model", found.group(0).strip()

    return None


def main():
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    command = (payload.get("tool_input") or {}).get("command", "")
    result = verdict(command)
    if result is None:
        sys.exit(0)

    description, matched = result
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "deny",
                    "permissionDecisionReason": (
                        f"Blocked: this command contains {description} "
                        f"({matched!r}). SQL Server is read-only for this app — "
                        "the DBA owns it. The app's own database on the primary "
                        "connection is unrestricted."
                    ),
                }
            }
        )
    )
    sys.exit(0)


if __name__ == "__main__":
    main()
