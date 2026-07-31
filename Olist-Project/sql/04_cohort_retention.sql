/* ============================================================
   04_cohort_retention.sql
   Cohort retention matrix.

   Output: CLEAN.COHORT_RETENTION (long format)

   A view rather than a table: the aggregation is small and cheap,
   so it stays automatically in sync with ORDERS_FEATURES.
   ============================================================ */

USE WAREHOUSE OLIST_WH;
USE DATABASE  OLIST_DB;
USE SCHEMA    CLEAN;

CREATE OR REPLACE VIEW CLEAN.COHORT_RETENTION AS
WITH cohort_counts AS (
    SELECT
        cohort_month,
        cohort_index,
        COUNT(DISTINCT customer_unique_id) AS n_customers
    FROM CLEAN.ORDERS_FEATURES
    GROUP BY cohort_month, cohort_index
),
cohort_size AS (
    -- Index 1 is the acquisition month, i.e. the 100% baseline.
    SELECT cohort_month, n_customers AS cohort_size
    FROM cohort_counts
    WHERE cohort_index = 1
)
SELECT
    c.cohort_month,
    c.cohort_index,
    c.n_customers,
    s.cohort_size,
    ROUND(c.n_customers / NULLIF(s.cohort_size, 0), 4) AS retention_rate
FROM cohort_counts c
JOIN cohort_size   s ON c.cohort_month = s.cohort_month;


/* ---------- The retention triangle ----------
   MAX(CASE WHEN ...) is the SQL idiom for pivoting: one column per
   value, with the aggregate selecting the single non-null entry.
   Month 1 is 100% across the board; the drop to month 2 is the
   "retention cliff".
   ------------------------------------------- */
SELECT
    cohort_month,
    MAX(cohort_size) AS cohort_size,
    MAX(CASE WHEN cohort_index = 1 THEN retention_rate END) AS month_1,
    MAX(CASE WHEN cohort_index = 2 THEN retention_rate END) AS month_2,
    MAX(CASE WHEN cohort_index = 3 THEN retention_rate END) AS month_3,
    MAX(CASE WHEN cohort_index = 4 THEN retention_rate END) AS month_4,
    MAX(CASE WHEN cohort_index = 5 THEN retention_rate END) AS month_5,
    MAX(CASE WHEN cohort_index = 6 THEN retention_rate END) AS month_6
FROM CLEAN.COHORT_RETENTION
GROUP BY cohort_month
ORDER BY cohort_month;
