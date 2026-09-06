# 🛒 Olist E-Commerce: Product Analytics & Growth Strategy

## 📈 Executive Summary
This project analyzes **100,000+ orders** to identify why customers churn and how to improve retention. By engineering **Acquisition Cohorts** and testing each explanation against the data, I found that the two intuitive causes of churn — slow logistics and a monthly pay cycle — are both unsupported, and that the retention problem is considerably worse than an averaged metric suggested.

The analysis is implemented twice: once in **Python/pandas** for exploration and statistical visualization, and once as a **SQL pipeline on Snowflake** to demonstrate the same logic in a cloud data warehouse. Running it both ways is what caught the three data-integrity bugs described below.

## 🚀 Key Business Insights
*   **Retention Cliff:** Only **0.46%** of customers return in Month 2 (437 of 95,420), and **97%** (92,507) never place a second order at all. The product is transactional, not habit-forming.
*   **Whale Concentration:** **8.4% of customers drive 36% of revenue** ($4.89M of $13.59M), at a lifetime spend of $612 vs $100 for everyone else — a concentration risk that argues for a VIP retention program.
*   **Logistics:** Repeat buyers received orders **0.73 days earlier** than one-time buyers (12.56 vs 11.83 days ahead of estimate). Both groups were delivered *early* on average, so delivery lateness does not explain the churn cliff. See the caveat below.
*   **No Monthly Cycle (a negative result):** I tested for a salary-cycle engagement pattern and found none — DAU varies only ~4% across the month. The apparent day-24 peak proved to be a single event, **Black Friday 2017**, which drove a 7× spike (1,151 users vs a ~160 baseline).

## 🛠 Tech Stack
*   **Python:** Pandas (Data Engineering), Seaborn (Statistical Visualization).
*   **Snowflake:** SQL warehouse pipeline — CTEs, window functions, conditional-aggregation pivots.
*   **Product Metrics:** Cohort Analysis, Retention Rate, DAU, AOV.

## 📂 Project Structure
*   `notebooks/`: End-to-end data cleaning and statistical analysis in pandas.
*   `sql/`: The Snowflake pipeline, numbered in execution order.
*   `results/`: Query output and Snowsight screenshots.
*   `data/`: Source and cleaned datasets.

The notebook reads from `../data/raw/` and unpacks the tracked zip on first run, so it executes from a fresh clone with no path edits.

---

## ❄️ Snowflake Pipeline

The warehouse follows a two-layer pattern: `RAW` holds source data exactly as loaded, `CLEAN` holds everything derived from it. Keeping them separate means a bad transform can always be rebuilt without re-ingesting.

```
CSV files
   │
   ▼
RAW.ORDERS · RAW.ORDER_ITEMS · RAW.CUSTOMERS
   │  join, deduplicate, handle nulls, flag IQR outliers
   ▼
CLEAN.ORDERS_CLEAN
   │  cohort month, cohort index, funnel step, delivery performance
   ▼
CLEAN.ORDERS_FEATURES
   │
   ├──▶ CLEAN.COHORT_RETENTION   (retention matrix)
   ├──▶ CLEAN.USER_LOYALTY       (churn vs. logistics)
   └──▶ CLEAN.DAU_TREND          (engagement heartbeat)
```

| Script | Purpose |
| --- | --- |
| [`01_setup.sql`](Olist-Project/sql/01_setup.sql) | Warehouse, database, and `RAW` schema; load verification |
| [`02_clean_layer.sql`](Olist-Project/sql/02_clean_layer.sql) | Joins, deduplication, null handling, IQR outlier flagging |
| [`03_features.sql`](Olist-Project/sql/03_features.sql) | Acquisition cohorts, funnel index, delivery performance |
| [`04_cohort_retention.sql`](Olist-Project/sql/04_cohort_retention.sql) | Retention matrix, long format plus a pivoted view |
| [`05_churn_whales_dau.sql`](Olist-Project/sql/05_churn_whales_dau.sql) | Churn root-cause, revenue concentration, DAU trend |

### Translating pandas to SQL
Porting the notebook surfaced patterns worth naming explicitly:

| pandas | Snowflake SQL |
| --- | --- |
| `groupby(...).transform('min')` | `MIN(...) OVER (PARTITION BY ...)` — keeps every row rather than collapsing |
| `.pivot()` | `MAX(CASE WHEN ... THEN ... END)` conditional aggregation |
| `.quantile(0.25)` | `PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY ...)` |
| intermediate DataFrames | chained CTEs (`WITH ... AS`) |

---

## 🧪 What the second implementation caught

Writing the same analysis twice is not busywork. Reconciling the two versions exposed three defects, each of which had changed a reported number and two of which had changed a *conclusion*.

**1. Item-level rows counted as orders.** The notebook counted orders per customer with `('order_id', 'count')`, but the joined table is item-level — a single three-item order was counted as three orders, misclassifying one-time buyers as loyal. Both implementations now use a distinct count (`COUNT(DISTINCT order_id)` / `nunique`).

The fix mattered. It raised the true one-time-buyer share to 97% and shrank the delivery-performance gap between repeat and one-time buyers from ~1.7 days to 0.73 — weak enough that the original "late delivery causes churn" conclusion no longer stands.

**2. The same grain error, a second time.** Re-auditing after the first fix turned up its twin. The column selection dropped `order_item_id` — the line-item key — before `drop_duplicates()`. Two units of the same product on one order differ *only* in that column, so they collapsed into one row and were discarded as duplicates: **10,225 genuine line items and $847,720 of revenue (6.2%)**, deleted silently. Total revenue is $13.59M, not the $12.74M reported earlier. Delivery performance is now averaged at the order level too, so a three-item order is not weighted 3× in a customer's score.

**3. A headline metric that was an artifact.** "Average Month-2 retention: 5.2%" was the unweighted mean of the per-cohort rates. The 2016-12 cohort contains exactly **one** customer, who returned — a 100% rate that by itself contributes 4.8pp of that 5.2%. Pooling the counts instead gives **0.46%** (437 of 95,420), and every cohort large enough to mean anything sits in a 0.22%–0.70% band. A ratio-of-averages is not the average ratio.

Two smaller corrections: the figure previously labelled AOV was the mean price of a single *line item*; true Average Order Value (order total ÷ order count) is **$137.75**, against an average item price of $83.97. And the customer-level whale segment, previously quoted without a query behind it, is now computed explicitly — under two independent definitions that agree to within 2pp.

---

## 🔍 Analytical Deep Dive

### 1. Cohort Retention Matrix
I calculated the **Cohort Index** to align users from different years onto a single timeline, then read the matrix by pooled counts rather than by averaging cohort rates. Month 2 is the critical window: **0.46%** of customers return in it, and 97% never return at all.

### 2. Testing the Churn Hypothesis (Anomaly Detection)
I correlated **Delivery Performance** with customer loyalty to test whether late shipping explains the retention cliff. It largely doesn't: repeat buyers were delivered 12.56 days ahead of the estimated date versus 11.83 for one-time buyers — a 0.73-day gap on a ~12-day cushion, with *both* groups arriving early on average.

Two reasons to treat even that gap cautiously: the segments are wildly unequal (2,913 repeat vs 92,507 one-time buyers), and repeat buyers have more deliveries averaged into their score, which smooths out bad experiences. Reporting this honestly is more useful than the tidier story — it redirects attention toward the more likely explanation for a 97% one-time-buyer rate, which is that Olist is a marketplace people use for a specific need rather than a destination they return to.

### 3. DAU "Heartbeat" Analysis
I tested the hypothesis that purchasing power is cyclical, peaking early in the month with the Brazilian salary cycle. **The data does not support it.** Weekly averages run 158.2 / 157.7 / 163.7 / 159.7 — a spread of about 4%, with no first-week advantage. Under a median rather than a mean, day 7 is the *lowest* day of the month.

Day 24 does average highest (190.4), but that is one event, not a pattern: excluding 20–30 November 2017 moves the peak to day 16 and drops the 22–28 week from 159.7 to 143.7. A single day — Black Friday, 2017-11-24, at 1,151 users against a ~160 baseline — was carrying the whole average.

Full series in [`results/`](Olist-Project/results/README.md).
