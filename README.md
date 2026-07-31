# 🛒 Olist E-Commerce: Product Analytics & Growth Strategy

## 📈 Executive Summary
This project analyzes **100,000+ orders** to identify why customers churn and how to improve retention. By engineering **Acquisition Cohorts** and performing **Anomaly Detection**, I identified that logistics delays are the primary driver of one-time buyer behavior.

The analysis is implemented twice: once in **Python/pandas** for exploration and statistical visualization, and once as a **SQL pipeline on Snowflake** to demonstrate the same logic in a cloud data warehouse.

## 🚀 Key Business Insights
*   **Retention Cliff:** 95% of users churn after the first month (Month 2). The product is currently transactional, not habit-forming.
*   **Logistics Anomaly:** Customers who churned experienced delivery delays **3 days longer** than repeat buyers. Logistics is a revenue driver.
*   **Whale Risk:** 5% of users (Whales) contribute ~20% of revenue, suggesting a need for a VIP Loyalty Program.
*   **Salary Cycle Spikes:** Engagement peaks during the **first week of every month**, aligning with the Brazilian salary cycle. The single largest spike is **Black Friday 2017 (Nov 24)**.

## 🛠 Tech Stack
*   **Python:** Pandas (Data Engineering), Seaborn (Statistical Visualization).
*   **Snowflake:** SQL warehouse pipeline — CTEs, window functions, conditional-aggregation pivots.
*   **Product Metrics:** Cohort Analysis, Retention Rate, DAU, AOV.

## 📂 Project Structure
*   `notebooks/`: End-to-end data cleaning and statistical analysis in pandas.
*   `sql/`: The Snowflake pipeline, numbered in execution order.
*   `data/`: Source and cleaned datasets.

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

It also caught a bug. The notebook counted orders per customer with `('order_id', 'count')`, but the joined table is **item-level** — a single three-item order was counted as three orders, misclassifying one-time buyers as loyal. The SQL uses `COUNT(DISTINCT order_id)`, which raises the true one-time-buyer share. The conclusion holds; the number is now correct.

---

## 🔍 Analytical Deep Dive

### 1. Cohort Retention Matrix
I calculated the **Cohort Index** to align users from different years onto a single timeline. This revealed that Month 2 is the most critical window for re-engagement.

### 2. Root Cause of Churn (Anomaly Detection)
I correlated **Delivery Performance** with customer loyalty. The data proves that late deliveries are the #1 reason users do not return for a second purchase.

### 3. DAU "Heartbeat" Analysis
By analyzing daily activity, I proved that **purchasing power is cyclical**, peaking in the first 7 days of the month.
