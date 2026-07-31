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

-- Day-of-month engagement. Day 24 looks like a peak (190.3 vs a ~160
-- baseline), which invites a "monthly salary cycle" story.
SELECT DAY(order_date)    AS day_of_month,
       ROUND(AVG(dau), 1) AS avg_dau
FROM CLEAN.DAU_TREND
GROUP BY 1
ORDER BY 1;

-- Largest single day is 2017-11-24, Black Friday: 1,151 users, ~7x baseline.
SELECT order_date, dau
FROM CLEAN.DAU_TREND
ORDER BY dau DESC
LIMIT 5;


/* ---------- C2. Sensitivity check on the day-of-month "cycle" ----------
   Before reporting a monthly pattern, test whether it survives removing
   the Black Friday window. It does not: the peak moves from day 24 to
   day 16, and the 22-28 bucket falls from 159.8 to 143.7.
   ---------------------------------------------------------------------- */

SELECT
    CASE
        WHEN DAY(order_date) BETWEEN  1 AND  7 THEN 'Days 01-07'
        WHEN DAY(order_date) BETWEEN  8 AND 14 THEN 'Days 08-14'
        WHEN DAY(order_date) BETWEEN 15 AND 21 THEN 'Days 15-21'
        WHEN DAY(order_date) BETWEEN 22 AND 28 THEN 'Days 22-28'
        ELSE                                        'Days 29-31'
    END                                        AS week_bucket,
    ROUND(AVG(dau), 1)                         AS avg_dau_all,
    ROUND(AVG(CASE WHEN order_date NOT BETWEEN '2017-11-20' AND '2017-11-30'
                   THEN dau END), 1)           AS avg_dau_excl_black_friday
FROM CLEAN.DAU_TREND
GROUP BY 1
ORDER BY 1;

-- Per-day view of the same test, plus a median. The median is
-- outlier-resistant, and under it day 7 is the LOWEST day of the month --
-- the opposite of a first-week salary-cycle peak.
SELECT
    DAY(order_date)                            AS day_of_month,
    ROUND(AVG(dau), 1)                         AS mean_dau_all,
    ROUND(AVG(CASE WHEN order_date NOT BETWEEN '2017-11-20' AND '2017-11-30'
                   THEN dau END), 1)           AS mean_dau_excl_black_friday,
    MEDIAN(dau)                                AS median_dau
FROM CLEAN.DAU_TREND
GROUP BY 1
ORDER BY 1;
