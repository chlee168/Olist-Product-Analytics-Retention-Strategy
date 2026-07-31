# Results

Query output from the Snowflake pipeline in [`../sql/`](../sql/), plus screenshots of the
warehouse itself. Every figure below is produced by a query in those scripts and can be
reproduced by running them in order.

Where the same metric exists in the pandas notebook, the two implementations agree — the
day-of-month DAU series below was computed independently in both and matches to the decimal.

---

## Retention

Average Month-2 retention across all cohorts: **5.2%**

Of 95,420 customers, **92,507 (97.0%) never placed a second order.**

*Source: `04_cohort_retention.sql`*

---

## Churn vs. delivery performance

| Segment | Customers | Avg days early |
| --- | ---: | ---: |
| One-time Buyer | 92,507 | 11.83 |
| Repeat Buyer | 2,913 | 12.58 |

Positive = delivered ahead of the promised date. The 0.75-day gap is small relative to a
~12-day average cushion, and **both segments were delivered early on average** — so delivery
lateness does not explain the retention cliff. The segments are also very unequal in size,
and repeat buyers have more deliveries averaged into their score, which smooths their result.

*Source: `05_churn_whales_dau.sql`*

---

## Revenue concentration ("whales")

Line-item level — outliers flagged by the 1.5 × IQR rule in `02_clean_layer.sql`:

| Price outlier | Items | Total revenue | % of revenue |
| --- | ---: | ---: | ---: |
| TRUE | 7,693 | $4,556,232.39 | 35.8% |
| FALSE | 94,732 | $8,187,691.61 | 64.2% |

Customer level:

| Whale | Customers | % of customers | % of revenue |
| --- | ---: | ---: | ---: |
| Yes | 7,597 | 8.0% | 36.1% |
| No | 87,823 | 92.0% | 63.9% |

**8% of customers drive 36% of revenue**, at an AOV of $592 versus $86.

*Source: `05_churn_whales_dau.sql`*

---

## Engagement by day of month

| Day | Avg DAU | Day | Avg DAU | Day | Avg DAU |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 160.3 | 12 | 157.3 | 23 | 146.2 |
| 2 | 158.5 | 13 | 161.2 | 24 | **190.3** |
| 3 | 154.0 | 14 | 166.4 | 25 | 161.8 |
| 4 | 163.0 | 15 | 165.4 | 26 | 162.2 |
| 5 | 152.7 | 16 | 176.7 | 27 | 153.6 |
| 6 | 161.7 | 17 | 156.8 | 28 | 148.4 |
| 7 | 157.3 | 18 | 168.2 | 29 | 139.6 |
| 8 | 155.7 | 19 | 165.6 | 30 | 146.4 |
| 9 | 153.0 | 20 | 160.6 | 31 | 149.8 |
| 10 | 147.9 | 21 | 152.8 | | |
| 11 | 162.8 | 22 | 156.1 | | |

Grouped into weeks:

| Days | Avg DAU |
| --- | ---: |
| 1–7 | 158.2 |
| 8–14 | 157.8 |
| 15–21 | 163.7 |
| 22–28 | 159.8 |

**There is no monthly engagement cycle.** The spread across the month is roughly 4%, and the
apparent day-24 peak is an artifact: excluding 20–30 Nov 2017 moves the peak to day 16 and
drops the 22–28 week from 159.8 to 143.7. Under a median instead of a mean, day 7 is the
*lowest* day of the month.

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

See [`screenshots/`](screenshots/). Suggested captures:

| Filename | What it shows |
| --- | --- |
| `01_database_explorer.png` | `OLIST_DB` object tree with the `RAW` and `CLEAN` schemas populated |
| `02_query_results.png` | A worksheet with SQL and its result grid |
| `03_query_history.png` | Query History — timestamped executions against real compute |
| `04_warehouse.png` | Admin → Warehouses, showing `OLIST_WH` and its size/auto-suspend settings |

Capture these before the Snowflake trial expires; account access ends with it.
