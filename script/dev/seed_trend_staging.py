"""Rebuild local stand-ins for the three tables the weekly ingests read, from
CS_Trend_Forecast.xlsx.

Copies each sheet the way the ETL does: by position, the sheet's header rows
included, no dates on the week columns, every row stamped with loaded_at. The
stand-ins carry the real tables' column names and the vertical sheet keeps its
dates as M/D/YYYY text, so the staging models, the column maps and the ingests
run for real.

    python3 script/dev/seed_trend_staging.py
    CSR_REPORTING_SQLITE=storage/development_staging.sqlite3 bin/rails runner \
      'pp Csr::Buffer::Ingest.new(force: true).call.message, Csr::Commit::Ingest.new(force: true).call.message'
"""
import openpyxl, sqlite3, sys, datetime, os

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/c/Users/gdlguzju/Desktop/CS_Trend_Forecast WK41.xlsx"
DB  = "/home/p_infinex/code/CSR_Agent/storage/development_staging.sqlite3"

BUFFER = ["FCP_PART", "FCP_SITE", "MANUFACTURER_PART", "MFG", "SUPPLIER_NAME", "MOQ", "SPQ", "FIXED_LEAD_TIME",
          "EFF_LEAD_TIME", "CUSTOMER_ID", "DELIVERY_ADDRESS", "CPN", "BIMWEEKS", "DAYSAVG",
          "SAFETY_STOCK_IGNORE_MOQ_SPQ", "SAFETY_STOCK_CONSIDER_SPQ", "ALLOCATED_CUSTOMER_ON_HAND",
          "BUFFER_COVERAGE_PERCENTAGE", "TYPE", "PAST"] + [f"F{n}" for n in range(21, 71)] + ["FUTURE"]
BUFFER_TEXT = {0, 1, 2, 3, 4, 9, 10, 11, 18}

VERTICAL = ["CUSTOMER_PART_CPN_DELIVERY_ADDRESS", "CUSTOMER", "PART", "CPN", "DELIVERY_ADDRESS", "TYPE", "DATE", "QTY",
            "DATE_LOG", "QUARTER_LOG", "QTY_VALUE", "SITE", "END_CUSTOMER", "ACCOUNT_MANAGER"]

# The sheet's first row is almost empty, so the ETL had no names to give.
COMMIT = (["NoName"] + [f"NoName{n}" for n in range(1, 7)] + ["F8"] + [f"NoName{n}" for n in range(7, 15)] + ["ETD"]
          + [f"F{n}" for n in range(18, 71)] + ["NoName15"])
COMMIT_TEXT = set(range(1, 10)) | {15}

wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
loaded_at = datetime.datetime.fromtimestamp(os.path.getmtime(SRC)).isoformat(sep=" ", timespec="seconds")
text = lambda v: None if v is None else str(v)

# The header row lands in the table with its text columns only: the others
# are numeric, and a label does not fit in them.
buffer = []
for n, r in enumerate(wb["CS - Buffer Readiness Projectio"].iter_rows(min_row=3, values_only=True)):
    buffer.append([text(v) if n or i in BUFFER_TEXT else None for i, v in enumerate(r)])

vertical = []
for r in wb["Vertical Commit (Hide)"].iter_rows(min_row=2, values_only=True):
    r = list(r)
    if isinstance(r[6], datetime.datetime):
        r[6] = f"{r[6].month}/{r[6].day}/{r[6].year}"
    vertical.append([text(v) for v in r])

commit = []
for n, r in enumerate(wb["Customer Commitment"].iter_rows(min_row=2, values_only=True)):
    header = n < 2  # the sheet's rows 2 and 3
    row = []
    for i, v in enumerate(r):
        if i in COMMIT_TEXT:
            row.append("" if v is None else str(v))
        elif i == 0:
            row.append(v.isoformat(sep=" ") if isinstance(v, datetime.datetime) else None)
        else:
            row.append(None if header or isinstance(v, str) else v)
    commit.append(row)

con = sqlite3.connect(DB)

def rebuild(table, columns, rows, kind=lambda i: "TEXT", stamped=True):
    assert all(len(r) == len(columns) for r in rows), table
    if stamped:  # the vertical table has no loaded_at
        columns, rows = columns + ["loaded_at"], [r + [loaded_at] for r in rows]
    con.execute(f'DROP TABLE IF EXISTS "{table}"')
    con.execute('CREATE TABLE "%s" (%s)' % (table, ", ".join(f'"{c}" {kind(i)}' for i, c in enumerate(columns))))
    con.executemany('INSERT INTO "%s" VALUES (%s)' % (table, ",".join("?" * len(columns))), rows)
    print(f"{table}: {len(rows)} filas")

rebuild("CS_tempTrendBufferReadinessProjection", BUFFER, buffer)
rebuild("CS_tempVerticalCommit", VERTICAL, vertical, stamped=False)
rebuild("CSR_CustomerCommitment", COMMIT, commit, kind=lambda i: "REAL" if i < len(COMMIT) and i and i not in COMMIT_TEXT else "TEXT")
con.commit()
con.close()
print("loaded_at:", loaded_at)
