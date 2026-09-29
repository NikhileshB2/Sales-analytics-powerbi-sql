-- =====================================================================
-- 03_build_star_schema.sql  |  stg_sales -> dimensions -> fact_sales
-- =====================================================================

-- ---- dim_date: one row per calendar day of the years in the data ----
WITH RECURSIVE d(dt) AS (
    SELECT DATE((SELECT MIN(order_date) FROM stg_sales), 'start of year')
    UNION ALL
    SELECT DATE(dt, '+1 day') FROM d
    WHERE dt < DATE((SELECT MAX(order_date) FROM stg_sales), 'start of year', '+1 year', '-1 day')
)
INSERT INTO dim_date
SELECT
    CAST(STRFTIME('%Y%m%d', dt) AS INTEGER),
    dt,
    CAST(STRFTIME('%Y', dt) AS INTEGER),
    (CAST(STRFTIME('%m', dt) AS INTEGER) + 2) / 3,
    'Q' || ((CAST(STRFTIME('%m', dt) AS INTEGER) + 2) / 3),
    CAST(STRFTIME('%m', dt) AS INTEGER),
    CASE STRFTIME('%m', dt)
        WHEN '01' THEN 'January'  WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April'    WHEN '05' THEN 'May'      WHEN '06' THEN 'June'
        WHEN '07' THEN 'July'     WHEN '08' THEN 'August'   WHEN '09' THEN 'September'
        WHEN '10' THEN 'October'  WHEN '11' THEN 'November' ELSE 'December' END,
    CASE STRFTIME('%m', dt)
        WHEN '01' THEN 'Jan' WHEN '02' THEN 'Feb' WHEN '03' THEN 'Mar' WHEN '04' THEN 'Apr'
        WHEN '05' THEN 'May' WHEN '06' THEN 'Jun' WHEN '07' THEN 'Jul' WHEN '08' THEN 'Aug'
        WHEN '09' THEN 'Sep' WHEN '10' THEN 'Oct' WHEN '11' THEN 'Nov' ELSE 'Dec' END,
    STRFTIME('%Y-%m', dt),
    CAST(STRFTIME('%d', dt) AS INTEGER),
    CASE STRFTIME('%w', dt) WHEN '0' THEN 7 ELSE CAST(STRFTIME('%w', dt) AS INTEGER) END,
    CASE STRFTIME('%w', dt)
        WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday' WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday' WHEN '6' THEN 'Saturday' ELSE 'Sunday' END,
    CASE WHEN STRFTIME('%w', dt) IN ('0', '6') THEN 1 ELSE 0 END
FROM d;

-- ---- dim_product (price tier thresholds are an assumption: >=1000 / >=100) ----
INSERT INTO dim_product (product_key, product_name, category, avg_price, price_tier)
SELECT ROW_NUMBER() OVER (ORDER BY product_category, product),
       product,
       product_category,
       ROUND(AVG(unit_price), 2),
       CASE WHEN AVG(unit_price) >= 1000 THEN 'Premium'
            WHEN AVG(unit_price) >= 100  THEN 'Mid-range'
            ELSE 'Budget' END
FROM stg_sales
GROUP BY product_category, product;

INSERT INTO dim_salesperson (salesperson_key, salesperson_name)
SELECT ROW_NUMBER() OVER (ORDER BY salesperson), salesperson
FROM (SELECT DISTINCT salesperson FROM stg_sales);

INSERT INTO dim_region (region_key, region_name)
SELECT ROW_NUMBER() OVER (ORDER BY region), region
FROM (SELECT DISTINCT region FROM stg_sales);

INSERT INTO dim_channel (channel_key, channel_name)
SELECT ROW_NUMBER() OVER (ORDER BY sales_channel), sales_channel
FROM (SELECT DISTINCT sales_channel FROM stg_sales);

-- ---- fact_sales ----
INSERT INTO fact_sales
SELECT
    ROW_NUMBER() OVER (ORDER BY s.order_id),
    s.order_id,
    CAST(STRFTIME('%Y%m%d', s.order_date) AS INTEGER),
    p.product_key,
    sp.salesperson_key,
    r.region_key,
    c.channel_key,
    s.customer_type,
    s.quantity,
    s.unit_price,
    s.discount,
    CASE WHEN s.discount = 0    THEN 'No discount'
         WHEN s.discount <= 0.05 THEN 'Low (1-5%)'
         WHEN s.discount <= 0.10 THEN 'Medium (6-10%)'
         ELSE 'High (>10%)' END,
    CASE WHEN s.discount = 0    THEN 1
         WHEN s.discount <= 0.05 THEN 2
         WHEN s.discount <= 0.10 THEN 3
         ELSE 4 END,
    ROUND(s.quantity * s.unit_price, 2),
    ROUND(s.quantity * s.unit_price - s.revenue, 2),
    s.revenue
FROM stg_sales s
JOIN dim_product     p  ON p.product_name     = s.product
JOIN dim_salesperson sp ON sp.salesperson_name = s.salesperson
JOIN dim_region      r  ON r.region_name      = s.region
JOIN dim_channel     c  ON c.channel_name     = s.sales_channel;
