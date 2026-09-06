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
WITH per_order AS (
    -- Collapse to one row per order first. ORDERS_FEATURES is item-level,
    -- and both metrics below are ORDER-level facts:
    --   * order_count -- a single 3-item order is one purchase, not three.
    --     Counting rows here is the bug that originally misclassified
    --     one-time buyers as loyal and reversed the churn conclusion.
    --   * delivery_performance -- one delivery per order. Averaging it over
    --     item rows weights a 3-item order 3x in the customer's score.
    SELECT
        customer_unique_id,
        order_id,
        SUM(price)                AS order_value,
        MIN(delivery_performance) AS delivery_performance  -- constant per order
    FROM CLEAN.ORDERS_FEATURES
    GROUP BY customer_unique_id, order_id
)
SELECT
    customer_unique_id,
    COUNT(*)                   AS order_count,
    AVG(delivery_performance)  AS avg_delivery_performance,
    SUM(order_value)           AS total_revenue,
    AVG(order_value)           AS avg_order_value,   -- true AOV, per customer
    COUNT(*) = 1               AS is_one_time_buyer
FROM per_order
GROUP BY customer_unique_id;

-- Expected: One-time 92,507 customers @ 11.83 days early
--           Repeat    2,913 customers @ 12.56 days early
-- A 0.73-day gap on a ~12-day cushion, with BOTH segments delivered early.
-- Logistics does not explain a 97% one-time-buyer rate.
SELECT
    CASE WHEN is_one_time_buyer THEN 'One-time Buyer' ELSE 'Repeat Buyer' END AS segment,
    COUNT(*)                                 AS customers,
    ROUND(AVG(avg_delivery_performance), 2)  AS avg_days_early
FROM CLEAN.USER_LOYALTY
GROUP BY is_one_time_buyer;


/* ---------- B. Whale revenue concentration ---------- */

/* B1. Line-item level.
   SUM(SUM(price)) OVER (): the inner SUM aggregates per group, the outer
   window SUM totals across all groups, giving percent-of-total in a
   single pass.

   NOTE ON NAMING: avg_item_price is the mean price of one line item. It is
   NOT Average Order Value -- an order can hold several items, so the two
   differ by a factor of ~1.6 here. True AOV is computed in B3.
   Expected: outlier 8,427 items / $4,839,551.84 / 35.6% / $574.29 avg
             normal 104,223 items / $8,752,091.86 / 64.4% / $83.97 avg   */
SELECT
    price_outlier,
    COUNT(*)                                              AS n_items,
    ROUND(SUM(price), 2)                                  AS total_revenue,
    ROUND(AVG(price), 2)                                  AS avg_item_price,
    ROUND(100 * SUM(price) / SUM(SUM(price)) OVER (), 1)  AS pct_of_revenue
FROM CLEAN.ORDERS_FEATURES
GROUP BY price_outlier;


/* B2. Customer level -- this is the "8% of customers drive 36% of revenue"
   figure, and it needs its own query. An outlier *item* is not the same
   thing as a high-value *customer*: someone who buys twenty cheap things
   can outspend someone who buys one expensive thing.

   Two definitions are computed below. They are built on different logic
   and land within 2pp of each other, which is what makes the finding
   trustworthy rather than an artifact of one arbitrary cut.             */

-- B2a. Whale = bought at least one IQR-flagged high-price item.
--      Expected: 7,986 customers (8.4%) / $4,891,269.89 (36.0%) / $612.48 avg
WITH cust AS (
    SELECT
        customer_unique_id,
        SUM(price)                                          AS total_spend,
        MAX(CASE WHEN price_outlier THEN 1 ELSE 0 END) = 1   AS is_whale
    FROM CLEAN.ORDERS_FEATURES
    GROUP BY customer_unique_id
)
SELECT
    is_whale,
    COUNT(*)                                                          AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                  AS pct_of_customers,
    ROUND(SUM(total_spend), 2)                                        AS revenue,
    ROUND(100 * SUM(total_spend) / SUM(SUM(total_spend)) OVER (), 1)  AS pct_of_revenue,
    ROUND(AVG(total_spend), 2)                                        AS avg_lifetime_spend
FROM cust
GROUP BY is_whale;

-- B2b. Whale = lifetime spend above the IQR fence of the customer-spend
--      distribution. Conceptually the cleaner definition: it ranks people
--      by what they are actually worth, not by one basket they bought.
--      Expected: fence $315.65 | 8,012 customers (8.4%) / $5,147,880.99
--                (37.9%) / $642.52 avg vs $96.60 for everyone else
WITH cust AS (
    SELECT customer_unique_id, SUM(price) AS total_spend
    FROM CLEAN.ORDERS_FEATURES
    GROUP BY customer_unique_id
),
fence AS (
    SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_spend)
         + 1.5 * (PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_spend)
                - PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_spend))
             AS upper_fence
    FROM cust
)
SELECT
    c.total_spend > f.upper_fence                                       AS is_whale,
    COUNT(*)                                                            AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                    AS pct_of_customers,
    ROUND(SUM(c.total_spend), 2)                                        AS revenue,
    ROUND(100 * SUM(c.total_spend) / SUM(SUM(c.total_spend)) OVER (), 1) AS pct_of_revenue,
    ROUND(AVG(c.total_spend), 2)                                        AS avg_lifetime_spend
FROM cust c
CROSS JOIN fence f
GROUP BY 1;


/* B3. True AOV: order total / order count. Expected: $137.75 over 98,666
   orders. Compare with the $83.97 "average item price" in B1 -- quoting
   that number as AOV understates the basket by ~40%.                    */
SELECT
    COUNT(*)                    AS orders,
    ROUND(AVG(order_value), 2)  AS aov
FROM (
    SELECT order_id, SUM(price) AS order_value
    FROM CLEAN.ORDERS_FEATURES
    GROUP BY order_id
);


/* ---------- C. Daily active users ---------- */

CREATE OR REPLACE VIEW CLEAN.DAU_TREND AS
SELECT
    order_purchase_timestamp::DATE     AS order_date,
    COUNT(DISTINCT customer_unique_id) AS dau
FROM CLEAN.ORDERS_FEATURES
GROUP BY 1;

-- Day-of-month engagement. Day 24 looks like a peak (190.4 vs a ~160
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
   day 16, and the 22-28 bucket falls from 159.7 to 143.7.
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
