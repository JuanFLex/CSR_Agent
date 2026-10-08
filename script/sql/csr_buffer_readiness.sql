/* CSR_BUFFER_READINESS
   -------------------
   The "Balance vs SS (Buffer Stock)" row of the Buffer Readiness projection,
   one row per part and week. The CSR portal reads this table and nothing else
   for Buffer (Reporting::BufferStaging); it never writes to it.

   It is filled from two tables the ETL already loads out of
   CS_Trend_Forecast.xlsx:

     CS_tempTrendBufferReadinessProjection  the projection, one column per week
     CS_tempVerticalCommit                  only for the date of the first week

   Why the second table: the projection's week columns arrive as F21..F70 and
   FUTURE, with the dates of the header row lost (NULL). Both sheets of the
   workbook start on the same Saturday, so the first real date of the commit
   sheet is the date of F21, and every column after it is seven days later.
   FUTURE is not a "beyond the horizon" bucket: it is the 51st week.

   ponytail: the week dates lean on the commit sheet starting the same
   Saturday as the projection (true in every file checked). If that ever
   stops holding, read the header row as text in the SSIS source (IMEX=1) and
   take the dates from it instead of from @first_week.
*/

/* ---- 1. Once: the table -------------------------------------------------- */

CREATE TABLE dbo.CSR_BUFFER_READINESS (
    FCP_PART                  nvarchar(200) NOT NULL,
    FCP_SITE                  nvarchar(50)  NULL,
    CPN                       nvarchar(200) NULL,
    MANUFACTURER_PART         nvarchar(200) NULL,
    SUPPLIER_NAME             nvarchar(255) NULL,
    CUSTOMER_ID               nvarchar(100) NULL,
    DELIVERY_ADDRESS          nvarchar(100) NULL,
    SAFETY_STOCK_CONSIDER_SPQ decimal(18,4) NULL,
    BUCKET_DATE               date          NOT NULL,  -- Saturday that names the week
    VS_SS                     decimal(18,4) NULL,      -- projected balance / safety stock
    LOADED_AT                 datetime      NOT NULL   -- the portal's "anything new?" check
);

CREATE INDEX IX_CSR_BUFFER_READINESS_BUCKET_DATE ON dbo.CSR_BUFFER_READINESS (BUCKET_DATE);
GO

/* ---- 2. Every run: the fill ----------------------------------------------
   Run it after the two data flows that load CS_tempTrendBufferReadinessProjection
   and CS_tempVerticalCommit, in the same package run, so both come from the
   same workbook. */

SET XACT_ABORT ON;

DECLARE @loaded_at  datetime = GETDATE();
DECLARE @first_week date = (
    SELECT MIN(TRY_CONVERT(date, [DATE], 101))   -- 'Past', 'Future' and the header become NULL
    FROM dbo.CS_tempVerticalCommit
);

-- A wrong anchor would shift all 51 weeks without a single error, so it has
-- to fail here instead. 1900-01-06 was a Saturday.
IF @first_week IS NULL OR DATEDIFF(DAY, '19000106', @first_week) % 7 <> 0
    THROW 50001, 'CSR_BUFFER_READINESS: the first week could not be read from CS_tempVerticalCommit, or it is not a Saturday. Table left as it was.', 1;

BEGIN TRANSACTION;

TRUNCATE TABLE dbo.CSR_BUFFER_READINESS;

INSERT INTO dbo.CSR_BUFFER_READINESS (
    FCP_PART, FCP_SITE, CPN, MANUFACTURER_PART, SUPPLIER_NAME, CUSTOMER_ID, DELIVERY_ADDRESS,
    SAFETY_STOCK_CONSIDER_SPQ, BUCKET_DATE, VS_SS, LOADED_AT
)
SELECT
    p.FCP_PART, p.FCP_SITE, p.CPN, p.MANUFACTURER_PART, p.SUPPLIER_NAME, p.CUSTOMER_ID, p.DELIVERY_ADDRESS,
    -- Through float first: it reads a number whether the column is numeric or
    -- text, including the scientific notation a tiny value can arrive in.
    TRY_CONVERT(decimal(18,4), TRY_CONVERT(float, p.SAFETY_STOCK_CONSIDER_SPQ)),
    DATEADD(DAY, 7 * (w.n - 21), @first_week),
    TRY_CONVERT(decimal(18,4), TRY_CONVERT(float, w.vs_ss)),
    @loaded_at
FROM dbo.CS_tempTrendBufferReadinessProjection AS p
CROSS APPLY (VALUES
    (21, p.F21), (22, p.F22), (23, p.F23), (24, p.F24), (25, p.F25), (26, p.F26), (27, p.F27),
    (28, p.F28), (29, p.F29), (30, p.F30), (31, p.F31), (32, p.F32), (33, p.F33), (34, p.F34),
    (35, p.F35), (36, p.F36), (37, p.F37), (38, p.F38), (39, p.F39), (40, p.F40), (41, p.F41),
    (42, p.F42), (43, p.F43), (44, p.F44), (45, p.F45), (46, p.F46), (47, p.F47), (48, p.F48),
    (49, p.F49), (50, p.F50), (51, p.F51), (52, p.F52), (53, p.F53), (54, p.F54), (55, p.F55),
    (56, p.F56), (57, p.F57), (58, p.F58), (59, p.F59), (60, p.F60), (61, p.F61), (62, p.F62),
    (63, p.F63), (64, p.F64), (65, p.F65), (66, p.F66), (67, p.F67), (68, p.F68), (69, p.F69),
    (70, p.F70), (71, p.FUTURE)
) AS w (n, vs_ss)
WHERE p.[TYPE] = 'Balance vs SS (Buffer Stock)'
  AND p.FCP_PART IS NOT NULL;

COMMIT TRANSACTION;

/* ---- 3. Check ------------------------------------------------------------
   Expect one row per part and week: parts x 51, weeks a year apart.

SELECT COUNT(*)                 AS rows_loaded,
       COUNT(DISTINCT FCP_PART) AS parts,
       COUNT(DISTINCT BUCKET_DATE) AS weeks,
       MIN(BUCKET_DATE)         AS first_week,
       MAX(BUCKET_DATE)         AS last_week,
       MAX(LOADED_AT)           AS loaded_at
FROM dbo.CSR_BUFFER_READINESS;
*/
