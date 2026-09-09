-- Read-only verification of the reporting connection.
--
-- Every statement here is a SELECT. Nothing creates, alters or writes, and the
-- permission check below proves that on purpose rather than by attempting a
-- write and seeing it fail.
--
-- Run against the database holding CSR_OSOR_AMERICAS, as the login the app will
-- use (CSR_READONLY_USER). Paste the results back and each one settles a
-- specific open question.

-- ---------------------------------------------------------------------------
-- 1. Which login is this, and is it actually read-only?
--
-- Settles: whether the credentials are safe to hand the app. can_select should
-- be 1; every other column should be 0. If any write permission comes back 1,
-- the login is not a db_datareader and should not be used here.
--
-- If the can_* columns come back NULL, the table did not resolve under the
-- login's default schema — qualify it ('dbo.CSR_OSOR_AMERICAS') and rerun. NULL
-- means "could not tell", not "no permission", so do not read it as a pass.
-- ---------------------------------------------------------------------------
SELECT
    SUSER_SNAME()                                                          AS login_name,
    USER_NAME()                                                            AS database_user,
    DB_NAME()                                                              AS database_name,
    HAS_PERMS_BY_NAME('CSR_OSOR_AMERICAS', 'OBJECT', 'SELECT')             AS can_select,
    HAS_PERMS_BY_NAME('CSR_OSOR_AMERICAS', 'OBJECT', 'INSERT')             AS can_insert,
    HAS_PERMS_BY_NAME('CSR_OSOR_AMERICAS', 'OBJECT', 'UPDATE')             AS can_update,
    HAS_PERMS_BY_NAME('CSR_OSOR_AMERICAS', 'OBJECT', 'DELETE')             AS can_delete,
    HAS_PERMS_BY_NAME('CSR_OSOR_AMERICAS', 'OBJECT', 'ALTER')              AS can_alter;

-- Roles the login carries, for the same question from the other side.
SELECT r.name AS role_name
FROM sys.database_role_members rm
JOIN sys.database_principals r ON r.principal_id = rm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = rm.member_principal_id
WHERE m.name = USER_NAME()
ORDER BY r.name;

-- ---------------------------------------------------------------------------
-- 2. Exact column names, with their real capitalisation.
--
-- Settles: whether Csr::Osor::ColumnMap matches reality. The map keys on the
-- lower-cased name, so case itself is not the risk — a name that differs by a
-- character is. Compare this list against the COLUMNS hash in
-- app/services/csr/osor/column_map.rb.
--
-- This is the single most likely thing to be wrong, and it fails silently:
-- an unmapped column just arrives as nil rather than raising.
-- ---------------------------------------------------------------------------
SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    NUMERIC_PRECISION,
    NUMERIC_SCALE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'CSR_OSOR_AMERICAS'
ORDER BY ORDINAL_POSITION;

-- ---------------------------------------------------------------------------
-- 3. Volume and freshness.
--
-- Settles: the shrink-tolerance guard, which refuses to activate a snapshot
-- more than 30% smaller than the last good one. total_rows tells us whether
-- ~11,354 (the figure from the Excel export) is the normal size.
--
-- watermark is what the ingest polls to notice your truncate+load finished.
-- If it comes back NULL, lastupdate is not populated and the ingest needs a
-- different trigger.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)              AS total_rows,
    MAX(lastupdate)       AS watermark,
    MIN(lastupdate)       AS oldest_row,
    COUNT(DISTINCT CAST(lastupdate AS DATE)) AS distinct_load_dates
FROM CSR_OSOR_AMERICAS;

-- ---------------------------------------------------------------------------
-- 4. The three assumptions the model is built on.
--
-- 4a. MPN population. The whole app keys on CPN|MPN, and you said MPN is
--     normally populated. mpn_missing is how many order lines would arrive
--     without a key. On the Excel export this was 34 of 11,354 (0.3%). A
--     materially larger share here means the key needs a different source.
-- ---------------------------------------------------------------------------
SELECT
    COUNT(*)                                                          AS total_rows,
    SUM(CASE WHEN MPN     IS NULL OR LTRIM(RTRIM(MPN))     = '' THEN 1 ELSE 0 END) AS mpn_missing,
    SUM(CASE WHEN CPN_EDI IS NULL OR LTRIM(RTRIM(CPN_EDI)) = '' THEN 1 ELSE 0 END) AS cpn_missing,
    SUM(CASE WHEN ITEM    IS NULL OR LTRIM(RTRIM(ITEM))    = '' THEN 1 ELSE 0 END) AS fpn_missing
FROM CSR_OSOR_AMERICAS;

-- 4b. Plants. The Excel export carried three (702FCS, 702AAA, 702CSD) while
--     the Kinaxis buffer file is frozen at a single site. This is the dimension
--     that stops being collapsible when Asia and Europe arrive, and it feeds
--     the "what is BP Code" question for Alejandro.
SELECT SoWhs, COUNT(*) AS lines
FROM CSR_OSOR_AMERICAS
GROUP BY SoWhs
ORDER BY lines DESC;

-- 4c. Misses. A line is late when the committed date lands after the need date.
--     The Excel export gave 6,965 of 10,927 datable lines, of which 114 differ
--     only by time of day on the same date — the open question for Alejandro is
--     whether the comparison should be by day instead of by timestamp.
SELECT
    COUNT(*)                                                                    AS datable_lines,
    SUM(CASE WHEN COMMDELDATE > PLANDELDATE THEN 1 ELSE 0 END)                  AS misses_by_timestamp,
    SUM(CASE WHEN CAST(COMMDELDATE AS DATE) > CAST(PLANDELDATE AS DATE) THEN 1 ELSE 0 END) AS misses_by_day
FROM CSR_OSOR_AMERICAS
WHERE PLANDELDATE IS NOT NULL
  AND COMMDELDATE IS NOT NULL
  AND PLANDELDATE > '1970-01-02'
  AND COMMDELDATE > '1970-01-02';

-- 4d. The epoch sentinel. Baan writes 1970-01-01 where it means "no date", and
--     the ingest discards those. This confirms the convention is real and shows
--     how many dates it affects.
SELECT
    SUM(CASE WHEN PLANDELDATE <= '1970-01-02' THEN 1 ELSE 0 END) AS pdd_epoch,
    SUM(CASE WHEN COMMDELDATE <= '1970-01-02' THEN 1 ELSE 0 END) AS cdd_epoch,
    SUM(CASE WHEN PLANDELDATE IS NULL THEN 1 ELSE 0 END)         AS pdd_null,
    SUM(CASE WHEN COMMDELDATE IS NULL THEN 1 ELSE 0 END)         AS cdd_null
FROM CSR_OSOR_AMERICAS;

-- ---------------------------------------------------------------------------
-- 5. One sample row, to eyeball the shape.
--
-- Settles nothing on its own, but it is the fastest way to spot a column whose
-- content is not what its name suggests.
-- ---------------------------------------------------------------------------
SELECT TOP 1 *
FROM CSR_OSOR_AMERICAS
WHERE MPN IS NOT NULL
  AND CPN_EDI IS NOT NULL;
