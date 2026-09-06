/* ============================================================
   02_clean_layer.sql
   Join the three source tables and apply data-integrity rules.

   Output: CLEAN.ORDERS_CLEAN (item-level grain)
   ============================================================ */

USE WAREHOUSE OLIST_WH;
USE DATABASE  OLIST_DB;

CREATE SCHEMA IF NOT EXISTS CLEAN;

CREATE OR REPLACE TABLE CLEAN.ORDERS_CLEAN AS
WITH joined AS (
    -- DISTINCT removes exact duplicate rows introduced by the joins.
    --
    -- order_item_id MUST stay in the projection. It is the line-item key:
    -- two units of the same product on one order are two legitimate rows
    -- that differ only in this column. Dropping it before the DISTINCT
    -- collapsed them into one, silently deleting 10,225 real line items
    -- and $847,720 of revenue.
    SELECT DISTINCT
        o.order_id,
        i.order_item_id,
        c.customer_unique_id,
        COALESCE(o.order_status, 'unknown')  AS order_status,
        o.order_purchase_timestamp,
        i.price,
        i.freight_value,
        i.product_id,
        c.customer_city,
        c.customer_state,
        -- Pulled in here (rather than re-joined later) because the
        -- churn analysis in 05 needs them.
        o.order_delivered_customer_date,
        o.order_estimated_delivery_date
    FROM RAW.ORDERS           o
    LEFT JOIN RAW.ORDER_ITEMS i ON o.order_id    = i.order_id
    LEFT JOIN RAW.CUSTOMERS   c ON o.customer_id = c.customer_id
),
filtered AS (
    -- Cohort analysis is impossible without a user ID, a price, and
    -- a timestamp, so rows missing any of the three are dropped.
    SELECT *
    FROM joined
    WHERE customer_unique_id       IS NOT NULL
      AND price                    IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL
),
bounds AS (
    -- Standard 1.5 * IQR fences, computed once over the whole set.
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price) AS q3
    FROM filtered
)
-- Outliers are flagged, not removed: high-value "whale" orders are a
-- real segment worth analysing, they just shouldn't distort AOV.
SELECT
    f.*,
    (f.price < b.q1 - 1.5 * (b.q3 - b.q1)
     OR f.price > b.q3 + 1.5 * (b.q3 - b.q1)) AS price_outlier
FROM filtered f
CROSS JOIN bounds b;


/* ---------- Verify ---------- */
-- Expected: 112,650 rows | 98,666 orders | 95,420 customers
--           $13,591,643.70 revenue | 8,427 outliers flagged
-- Row count must equal RAW.ORDER_ITEMS: every line item survives, and the
-- DISTINCT now removes nothing. If it drops below 112,650, the line-item
-- key has gone missing again.
SELECT COUNT(*)                                         AS total_rows,
       COUNT(DISTINCT order_id)                         AS unique_orders,
       COUNT(DISTINCT customer_unique_id)               AS unique_customers,
       ROUND(SUM(price), 2)                             AS total_revenue,
       SUM(CASE WHEN price_outlier THEN 1 ELSE 0 END)   AS outliers_flagged
FROM CLEAN.ORDERS_CLEAN;
