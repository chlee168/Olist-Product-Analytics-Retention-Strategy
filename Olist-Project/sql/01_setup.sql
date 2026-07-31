/* ============================================================
   01_setup.sql
   Provision the warehouse, database, and RAW schema.

   Run once. The RAW tables are then populated from the source
   CSVs in data/raw/ via Snowsight's "Load Data" wizard
   (header skipped, fields optionally enclosed by double quotes).
   ============================================================ */

-- Compute engine. AUTO_SUSPEND keeps trial credits from burning idle.
CREATE WAREHOUSE IF NOT EXISTS OLIST_WH
  WITH WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME  = TRUE;

CREATE DATABASE IF NOT EXISTS OLIST_DB;

-- RAW holds source data as-loaded; CLEAN (created in 02) holds
-- transformed output. Keeping them separate means a bad transform
-- is always recoverable without re-ingesting.
CREATE SCHEMA IF NOT EXISTS OLIST_DB.RAW;

USE WAREHOUSE OLIST_WH;
USE DATABASE  OLIST_DB;
USE SCHEMA    RAW;


/* ---------- Verify the load ---------- */
-- Expected: ORDERS ~99,441 | ORDER_ITEMS ~112,650 | CUSTOMERS ~99,441
-- ORDER_ITEMS is larger by design: one order can contain many items.
SELECT 'ORDERS'      AS table_name, COUNT(*) AS row_count FROM ORDERS
UNION ALL
SELECT 'ORDER_ITEMS', COUNT(*) FROM ORDER_ITEMS
UNION ALL
SELECT 'CUSTOMERS',   COUNT(*) FROM CUSTOMERS;
