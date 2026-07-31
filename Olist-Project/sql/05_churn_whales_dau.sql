/* ============================================================
   05_churn_whales_dau.sql
   The three business questions:
     A) Do late deliveries cause churn?
     B) How concentrated is revenue among high-value buyers?
     C) When are users actually active?

   Outputs: CLEAN.USER_LOYALTY, CLEAN.DAU_TREND
   ============================================================ */

USE WAREHOUSE OLIST_WH;
USE DATABASE  OLIST_DB;
USE SCHEMA    CLEAN;


/* ---------- A. Churn vs. logistics ---------- */

CREATE OR REPLACE VIEW CLEAN.USER_LOYALTY AS
SELECT
    customer_unique_id,
    -- COUNT(DISTINCT order_id), not COUNT(*): ORDERS_FEATURES is
    -- item-level, so a single 3-item order would otherwise look like
    -- three orders and misclassify a one-time buyer as loyal.
    COUNT(DISTINCT order_id)      AS order_count,
    AVG(delivery_performance)     AS avg_delivery_performance,
    SUM(price)                    AS total_revenue,
    COUNT(DISTINCT order_id) = 1  AS is_one_time_buyer
FROM CLEAN.ORDERS_FEATURES
GROUP BY customer_unique_id;

-- Repeat buyers enjoy a wider early-delivery cushion than one-time
-- buyers: logistics performance tracks with retention.
SELECT
    CASE WHEN is_one_time_buyer THEN 'One-time Buyer' ELSE 'Repeat Buyer' END AS segment,
    COUNT(*)                                 AS customers,
    ROUND(AVG(avg_delivery_performance), 2)  AS avg_days_early
FROM CLEAN.USER_LOYALTY
GROUP BY is_one_time_buyer;


/* ---------- B. Whale revenue concentration ---------- */

-- SUM(SUM(price)) OVER (): the inner SUM aggregates per group, the
-- outer window SUM totals across all groups, giving percent-of-total
-- in a single pass.
SELECT
    price_outlier,
    COUNT(*)                                              AS n_items,
    ROUND(SUM(price), 2)                                  AS total_revenue,
    ROUND(AVG(price), 2)                                  AS avg_price,
    ROUND(100 * SUM(price) / SUM(SUM(price)) OVER (), 1)  AS pct_of_revenue
FROM CLEAN.ORDERS_FEATURES
GROUP BY price_outlier;


/* ---------- C. Daily active users ---------- */

CREATE OR REPLACE VIEW CLEAN.DAU_TREND AS
SELECT
    order_purchase_timestamp::DATE     AS order_date,
    COUNT(DISTINCT customer_unique_id) AS dau
FROM CLEAN.ORDERS_FEATURES
GROUP BY 1;

-- Engagement clusters in the first week of the month, matching the
-- Brazilian salary cycle.
SELECT DAY(order_date)    AS day_of_month,
       ROUND(AVG(dau), 1) AS avg_dau
FROM CLEAN.DAU_TREND
GROUP BY 1
ORDER BY 1;

-- Largest spike is 2017-11-24, Black Friday.
SELECT order_date, dau
FROM CLEAN.DAU_TREND
ORDER BY dau DESC
LIMIT 5;
