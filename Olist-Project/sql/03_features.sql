/* ============================================================
   03_features.sql
   Derive the product-analytics features: acquisition cohorts,
   funnel position, and delivery performance.

   Output: CLEAN.ORDERS_FEATURES
   ============================================================ */

USE WAREHOUSE OLIST_WH;
USE DATABASE  OLIST_DB;
USE SCHEMA    CLEAN;

CREATE OR REPLACE TABLE CLEAN.ORDERS_FEATURES AS
WITH with_month AS (
    SELECT
        *,
        DATE_TRUNC('MONTH', order_purchase_timestamp)::DATE AS order_month
    FROM CLEAN.ORDERS_CLEAN
),
with_cohort AS (
    -- A window function, not GROUP BY: every original row is kept and
    -- stamped with its customer's first-ever purchase month.
    SELECT
        *,
        MIN(order_month) OVER (PARTITION BY customer_unique_id) AS cohort_month
    FROM with_month
)
SELECT
    *,
    -- Age of the customer relationship. Index 1 = acquisition month,
    -- index 3 = returned two months after joining.
    DATEDIFF('month', cohort_month, order_month) + 1 AS cohort_index,

    CASE order_status
        WHEN 'created'   THEN 1
        WHEN 'approved'  THEN 2
        WHEN 'shipped'   THEN 3
        WHEN 'delivered' THEN 4
        ELSE 0
    END AS funnel_step_index,

    -- Positive = arrived ahead of the promised date.
    DATEDIFF('day', order_delivered_customer_date, order_estimated_delivery_date) AS delivery_performance,
    DATEDIFF('day', order_delivered_customer_date, order_estimated_delivery_date) < 0 AS is_late
FROM with_cohort;


/* ---------- Verify ---------- */
-- A known repeat buyer: expect cohort_index 1 and 2 on the same cohort_month.
SELECT customer_unique_id, order_month, cohort_month, cohort_index, funnel_step_index
FROM CLEAN.ORDERS_FEATURES
WHERE customer_unique_id = '7c396fd4830fd04220f754e42b4e5bff'
ORDER BY order_month;
