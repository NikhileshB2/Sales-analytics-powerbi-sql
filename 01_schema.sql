-- =====================================================================
-- 01_schema.sql  |  Staging table + star schema (dimensions + fact)
-- Dialect: ANSI-style SQL, tested on SQLite. See README for the
-- SQL Server / PostgreSQL / MySQL differences (dates + auto-increment).
-- =====================================================================

DROP VIEW  IF EXISTS vw_sales_flat;
DROP VIEW  IF EXISTS vw_monthly_summary;
DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_salesperson;
DROP TABLE IF EXISTS dim_region;
DROP TABLE IF EXISTS dim_channel;
DROP TABLE IF EXISTS stg_sales;

-- Staging: one row per order, exactly as delivered (dates standardised to ISO by the loader)
CREATE TABLE stg_sales (
    order_id         TEXT,
    order_date       TEXT,      -- YYYY-MM-DD
    region           TEXT,
    sales_channel    TEXT,
    customer_type    TEXT,
    product_category TEXT,
    product          TEXT,
    salesperson      TEXT,
    quantity         INTEGER,
    unit_price       REAL,
    discount         REAL,      -- fraction, e.g. 0.05 = 5%
    revenue          REAL       -- net revenue after discount
);

CREATE TABLE dim_date (
    date_key      INTEGER PRIMARY KEY,   -- yyyymmdd
    full_date     TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    quarter       INTEGER NOT NULL,
    quarter_name  TEXT    NOT NULL,      -- Q1..Q4
    month_num     INTEGER NOT NULL,
    month_name    TEXT    NOT NULL,
    month_short   TEXT    NOT NULL,
    year_month    TEXT    NOT NULL,      -- 2026-03 (sortable)
    day_of_month  INTEGER NOT NULL,
    day_of_week   INTEGER NOT NULL,      -- 1 = Monday ... 7 = Sunday
    day_name      TEXT    NOT NULL,
    is_weekend    INTEGER NOT NULL       -- 1 / 0
);

CREATE TABLE dim_product (
    product_key  INTEGER PRIMARY KEY,
    product_name TEXT NOT NULL,
    category     TEXT NOT NULL,
    avg_price    REAL NOT NULL,
    price_tier   TEXT NOT NULL           -- Premium / Mid-range / Budget
);

CREATE TABLE dim_salesperson (
    salesperson_key  INTEGER PRIMARY KEY,
    salesperson_name TEXT NOT NULL
);

CREATE TABLE dim_region (
    region_key  INTEGER PRIMARY KEY,
    region_name TEXT NOT NULL
);

CREATE TABLE dim_channel (
    channel_key  INTEGER PRIMARY KEY,
    channel_name TEXT NOT NULL
);

CREATE TABLE fact_sales (
    sales_key           INTEGER PRIMARY KEY,
    order_id            TEXT    NOT NULL UNIQUE,
    date_key            INTEGER NOT NULL REFERENCES dim_date(date_key),
    product_key         INTEGER NOT NULL REFERENCES dim_product(product_key),
    salesperson_key     INTEGER NOT NULL REFERENCES dim_salesperson(salesperson_key),
    region_key          INTEGER NOT NULL REFERENCES dim_region(region_key),
    channel_key         INTEGER NOT NULL REFERENCES dim_channel(channel_key),
    customer_type       TEXT    NOT NULL,      -- New / Returning
    quantity            INTEGER NOT NULL,
    unit_price          REAL    NOT NULL,
    discount_pct        REAL    NOT NULL,
    discount_band       TEXT    NOT NULL,
    discount_band_order INTEGER NOT NULL,
    gross_revenue       REAL    NOT NULL,      -- quantity * unit_price
    discount_amount     REAL    NOT NULL,      -- gross - net
    net_revenue         REAL    NOT NULL       -- revenue from source file
);

CREATE INDEX ix_fact_date     ON fact_sales(date_key);
CREATE INDEX ix_fact_product  ON fact_sales(product_key);
CREATE INDEX ix_fact_sp       ON fact_sales(salesperson_key);
CREATE INDEX ix_fact_region   ON fact_sales(region_key);
CREATE INDEX ix_fact_channel  ON fact_sales(channel_key);
