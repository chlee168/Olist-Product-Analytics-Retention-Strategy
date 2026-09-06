# Results

Query output from the Snowflake pipeline in [`../sql/`](../sql/), plus screenshots of the
warehouse itself. Every figure below is produced by a query in those scripts and can be
reproduced by running them in order.

The pandas notebook computes the same metrics independently and agrees on all of them,
including delivery performance — the notebook normalises both dates to midnight so that
its day count matches Snowflake's `DATEDIFF('day', ...)` rather than truncating a partial
day.

---

## Pipeline scale

| Stage | Rows |
| --- | ---: |
| `RAW.ORDERS` | 99,441 |
| `RAW.ORDER_ITEMS` | 112,650 |
| `RAW.CUSTOMERS` | 99,441 |
| `CLEAN.ORDERS_CLEAN` (item-level) | 112,650 |
| Distinct orders | 98,666 |
| Distinct customers | 95,420 |
| Total revenue | $13,591,643.70 |

`ORDERS_CLEAN` matching `RAW.ORDER_ITEMS` row-for-row is the check that the line-item key
survived the join: the `DISTINCT` removes nothing, because the joins introduce no true
duplicates. An earlier version dropped `order_item_id` before deduplicating and lost
10,225 real line items ($847,720).

*Source: `02_clean_layer.sql`*

---

## Retention

**437 of 95,420 customers (0.46%) returned in Month 2.**
Of the same 95,420, **92,507 (97.0%) never placed a second order.**

Per-cohort Month-2 rates, largest cohorts first:

| Cohort | Size | Returned in M2 | Rate |
| --- | ---: | ---: | ---: |
| 2017-11 | 7,217 | 40 | 0.55% |
| 2018-03 | 6,947 | 31 | 0.45% |
| 2018-01 | 6,983 | 24 | 0.34% |
| 2018-04 | 6,709 | 39 | 0.58% |
| 2018-05 | 6,604 | 35 | 0.53% |
| 2018-02 | 6,422 | 25 | 0.39% |
| 2017-12 | 5,442 | 12 | 0.22% |
| 2017-10 | 4,412 | 31 | 0.70% |
| … | | | |
| 2016-12 | **1** | 1 | **100.00%** |

Averaging that last column gives 5.2%, which is why this README previously reported it.
The number is an artifact: the 2016-12 cohort holds exactly one customer, and that single
100% row contributes 4.8 of the 5.2 percentage points. Every cohort with a meaningful size
sits between 0.22% and 0.70%. **Pool the numerators and denominators; do not average the
rates.**

*Source: `04_cohort_retention.sql`*

---

## Churn vs. delivery performance

| Segment | Customers | Avg days early |
| --- | ---: | ---: |
| One-time Buyer | 92,507 | 11.83 |
| Repeat Buyer | 2,913 | 12.56 |

Positive = delivered ahead of the promised date, averaged per order rather than per line
item. The 0.73-day gap is small relative to a ~12-day average cushion, and **both segments
were delivered early on average** — so delivery lateness does not explain the retention
cliff. The segments are also very unequal in size, and repeat buyers have more deliveries
averaged into their score, which smooths their result.

*Source: `05_churn_whales_dau.sql`*

---

## Revenue concentration ("whales")

Line-item level — outliers flagged by the 1.5 × IQR rule in `02_clean_layer.sql`
(fences: $-102.60 to $277.40):

| Price outlier | Items | Total revenue | % of revenue | Avg item price |
| --- | ---: | ---: | ---: | ---: |
| TRUE | 8,427 | $4,839,551.84 | 35.6% | $574.29 |
| FALSE | 104,223 | $8,752,091.86 | 64.4% | $83.97 |

Customer level. An outlier *item* is not the same thing as a high-value *customer*, so the
segment is computed two independent ways:

**A — bought at least one high-price item**

| Whale | Customers | % of customers | Revenue | % of revenue | Avg lifetime spend |
| --- | ---: | ---: | ---: | ---: | ---: |
| Yes | 7,986 | 8.4% | $4,891,269.89 | 36.0% | $612.48 |
| No | 87,434 | 91.6% | $8,700,373.81 | 64.0% | $99.51 |

**B — lifetime spend above the IQR fence of the customer spend distribution ($315.65)**

| Whale | Customers | % of customers | Revenue | % of revenue | Avg lifetime spend |
| --- | ---: | ---: | ---: | ---: | ---: |
| Yes | 8,012 | 8.4% | $5,147,880.99 | 37.9% | $642.52 |
| No | 87,408 | 91.6% | $8,443,762.71 | 62.1% | $96.60 |

Two definitions built on different logic, landing within 2pp of each other:
**roughly 8% of customers account for 36–38% of revenue.**

**Average Order Value: $137.75** across 98,666 orders (order total ÷ order count). This is
distinct from the $83.97 average *item* price above — an earlier version of this README
quoted the latter as AOV, understating the basket by about 40%.

*Source: `05_churn_whales_dau.sql`*

---

## Engagement by day of month

| Day | Avg DAU | Day | Avg DAU | Day | Avg DAU |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 160.3 | 12 | 157.4 | 23 | 146.2 |
| 2 | 158.5 | 13 | 161.2 | 24 | **190.4** |
| 3 | 154.0 | 14 | 166.4 | 25 | 161.8 |
| 4 | 163.0 | 15 | 165.4 | 26 | 162.2 |
| 5 | 152.7 | 16 | 176.6 | 27 | 153.6 |
| 6 | 161.7 | 17 | 156.8 | 28 | 148.4 |
| 7 | 157.3 | 18 | 168.2 | 29 | 139.6 |
| 8 | 155.7 | 19 | 165.6 | 30 | 146.4 |
| 9 | 153.0 | 20 | 160.6 | 31 | 149.8 |
| 10 | 147.9 | 21 | 152.8 | | |
| 11 | 162.8 | 22 | 156.0 | | |

Grouped into weeks:

| Days | Avg DAU | Excl. 20–30 Nov 2017 |
| --- | ---: | ---: |
| 1–7 | 158.2 | 158.2 |
| 8–14 | 157.7 | 157.7 |
| 15–21 | 163.7 | 162.8 |
| 22–28 | 159.7 | 143.7 |

**There is no monthly engagement cycle.** The spread across the month is roughly 4%, and the
apparent day-24 peak is an artifact: excluding 20–30 Nov 2017 moves the peak to day 16 and
drops the 22–28 week from 159.7 to 143.7. Under a median instead of a mean, day 7 is the
*lowest* day of the month (123.0).

These figures are unchanged by the line-item fix, as expected — DAU counts distinct
customers per day, so restoring duplicate line items cannot move it. That invariance is
itself a check on the fix.

The one genuine temporal signal is Black Friday:

| Date | DAU |
| --- | ---: |
| 2017-11-24 | 1,151 |
| 2017-11-25 | 491 |
| 2017-11-27 | 396 |
| 2017-11-26 | 383 |
| 2017-11-28 | 373 |

Against a ~160 baseline, that is a 7× single-day spike.

*Source: `05_churn_whales_dau.sql`*

---

## Screenshots

Captured from Snowsight in [`screenshots/`](screenshots/):

| File | What it shows |
| --- | --- |
| [`01_database_explorer.png`](screenshots/01_database_explorer.png) | `OLIST_DB` object tree — `RAW` and `CLEAN` schemas, 2 tables and 3 views |
| [`02_query_results.png`](screenshots/02_query_results.png) | The `DAU_TREND` view and day-of-month query, 31 rows returned in 70ms |
| [`03_query_history.png`](screenshots/03_query_history.png) | Query History — 23 timestamped executions with query IDs, on the `OLIST_WH` X-Small warehouse |
| [`04_user_loyalty_view.png`](screenshots/04_user_loyalty_view.png) | The `USER_LOYALTY` view definition, showing the `COUNT(DISTINCT order_id)` fix |

The `AVG_DAU` values visible in `02_query_results.png` (160.3, 158.5, 154.0, 163.0, 152.7) match the
pandas notebook exactly, confirming the two implementations agree.

> Note: `04_user_loyalty_view.png` predates the order-level rewrite of `USER_LOYALTY` and
> shows the previous view definition. Re-capture it after the next pipeline run.
