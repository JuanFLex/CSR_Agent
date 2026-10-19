"""Rebuild the local stand-in for CSR_DemandComparison from the Demand
Comparison workbook, the way the ETL copies its Data sheet.

Columns are named after the header text: uppercased, spaces to underscores,
% to PCT and $ to USD. The 52 week headers are dates, so they become F9, F10...
by position. Every row is stamped with loaded_at, the file's mtime. Only this
one table is dropped and recreated.

    python3 script/dev/seed_demand_staging.py
    CSR_REPORTING_SQLITE=storage/development_staging.sqlite3 bin/rails runner \
      'pp Csr::Demand::Ingest.new(force: true).call.message'
"""
import datetime, os, sqlite3, sys

import openpyxl

SRC = sys.argv[1] if len(sys.argv) > 1 else "/mnt/c/Users/gdlguzju/Desktop/Demand Comparison File - CS W42.xlsx"
DB = "/home/p_infinex/code/CSR_Agent/storage/development_staging.sqlite3"
TABLE = "CSR_DemandComparison"
TEXT_COLUMNS = 8  # the first eight are text; the rest are numbers

def column_name(cell, position):
    if isinstance(cell, datetime.datetime):
        return f"F{position}"
    return str(cell).strip().upper().replace("%", "PCT").replace("$", "USD").replace(" ", "_")

wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
rows = list(wb["Data"].iter_rows(values_only=True))
header = [column_name(cell, i + 1) for i, cell in enumerate(rows[0])]
loaded_at = datetime.datetime.fromtimestamp(os.path.getmtime(SRC)).strftime("%Y-%m-%d %H:%M:%S")

def value(v):
    if isinstance(v, datetime.datetime):
        return v.strftime("%Y-%m-%d")
    return v

data = [[value(v) for v in r] + [loaded_at] for r in rows[1:]]
columns = header + ["loaded_at"]
kinds = ["TEXT" if i < TEXT_COLUMNS else "REAL" for i in range(len(header))] + ["TEXT"]

con = sqlite3.connect(DB)
con.execute(f'DROP TABLE IF EXISTS "{TABLE}"')
defs = ", ".join('"%s" %s' % (c, k) for c, k in zip(columns, kinds))
con.execute('CREATE TABLE "%s" (%s)' % (TABLE, defs))
con.executemany('INSERT INTO "%s" VALUES (%s)' % (TABLE, ",".join("?" * len(columns))), data)
con.commit()
con.close()
print(f"{TABLE}: {len(data)} filas")
print("loaded_at:", loaded_at)
