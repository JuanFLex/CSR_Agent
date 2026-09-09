"""Rebuild a local stand-in for CSR_OSOR_AMERICAS from the OSOR Excel export.

Lets the ingest, the resolver and the summaries run against the real 11k rows
with no SQL Server to hand. It renames the export's headers to the names the
staging table actually uses, so the ColumnMap is exercised for real rather than
against a convenient fiction.

The stand-in lands in its own file and is reached through the `reporting`
connection, the same one production uses for SQL Server — the harness follows
the real code path rather than a shortcut around it.

    python3 script/dev/seed_osor_staging.py
    CSR_REPORTING_SQLITE=storage/development_staging.sqlite3 \
      bin/rails runner 'pp Csr::Osor::Ingest.new.call.message'

Superseded once slice 2 brings in roo and this becomes a rake task.
"""
import openpyxl, sqlite3, sys, datetime, os

SRC = "/mnt/c/Users/gdlguzju/OneDrive - Flex/Manuel/2026/Agosto 2026/csr app doctos/Americas_OSOR_03112026_Morning.xlsx"
DB  = "/home/p_infinex/code/CSR_Agent/storage/development_staging.sqlite3"

# Excel export header -> the name the column carries in CSR_OSOR_AMERICAS.
RENAME = {
 "BP NAME":"BP_NAME", "CPO Pos":"CPO_Pos", "PO Pos":"POPos", "PO Qty":"poqty",
 "PO Price":"Poprice", "PO Confirm Date":"PO_ConfirmDate", "PO Change Date":"PO_ChangeDate",
 "Error Condition":"Condition", "SO Status":"SO_Status", "Load":"LOAD",
 "Load Line Status":"LoadLineStatus", "FPN":"ITEM", "CPN":"CPN_EDI",
 "Baan Ordered":"Baan_Ordered", "SPQ / ORDER":"SPQ_ORDERED", "SO WHS":"SoWhs",
 "INV WHS":"WHS", "Inv WHS":"Inv_WHS", "PDD":"PLANDELDATE", "CDD":"COMMDELDATE",
 "PROMDD":"PROMDELDATE", "Cust Req Date":"CUSTREQDATE", "Days Preious CDD":"DaysPreviosCDD",
 "block codes":"block_codes", "Load General":"LoadGeneral", "Manufacturer":"manufacturers",
 "PO Activity":"poactivity", "Reference  A":"refa", "Ref B":"refb", "Project":"sourg",
}
def sqlname(h):
    h = (h or "").strip()
    if h in RENAME: return RENAME[h]
    if h.startswith("Del. Dates Status"): return "DatesCondition"
    if h.startswith("PPV"): return "ppv"
    return h

wb = openpyxl.load_workbook(SRC, read_only=True, data_only=True)
ws = wb["Sheet1"]
rows = ws.iter_rows(min_row=4, values_only=True)
header = [sqlname(h) for h in next(rows)]

# Keep only usable, unique column names.
keep, seen = [], set()
for i, h in enumerate(header):
    if h and h not in seen and h not in ("None",):
        seen.add(h); keep.append((i, h))
cols = [h for _, h in keep] + ["lastupdate"]

con = sqlite3.connect(DB)
con.execute("DROP TABLE IF EXISTS CSR_OSOR_AMERICAS")
con.execute("CREATE TABLE CSR_OSOR_AMERICAS (%s)" % ", ".join(f'"{c}" TEXT' for c in cols))

watermark = datetime.datetime.fromtimestamp(os.path.getmtime(SRC)).isoformat(sep=" ")
buf, n = [], 0
for r in rows:
    if all(v is None for v in r): continue
    out = []
    for i, _ in keep:
        v = r[i] if i < len(r) else None
        if isinstance(v, (datetime.datetime, datetime.date)):
            v = v.isoformat(sep=" ") if isinstance(v, datetime.datetime) else v.isoformat()
        out.append(None if v is None else str(v))
    buf.append(out + [watermark]); n += 1
    if len(buf) >= 2000:
        con.executemany("INSERT INTO CSR_OSOR_AMERICAS VALUES (%s)" % ",".join("?"*len(cols)), buf); buf=[]
if buf:
    con.executemany("INSERT INTO CSR_OSOR_AMERICAS VALUES (%s)" % ",".join("?"*len(cols)), buf)
con.commit()
print(f"CSR_OSOR_AMERICAS simulada: {n} filas, {len(cols)} columnas")
print("watermark:", watermark)
mapped = [c for c in cols if c.lower() in {
 "cpn_edi","mpn","item","plandeldate","commdeldate","baan_ordered","cpo","cpo_pos","so","pos"}]
print("columnas clave presentes:", mapped)
con.close()
